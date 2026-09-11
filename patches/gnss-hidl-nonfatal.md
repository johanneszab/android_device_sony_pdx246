# Binary patch: make the GNSS HAL's HIDL registration non-fatal

Applies to: vendor/sony/pdx246/proprietary/vendor/bin/hw/android.hardware.gnss-aidl-service-qti
Re-extracting the blob restores the unpatched binary, so THIS PATCH MUST BE
RE-APPLIED after any extract-files run.

NOTE: the proprietary copy is NOT byte-identical to the raw stock dump --
extract-utils post-processes blobs (soname/dependency fixups), so do not
"restore" it by copying from the dump. Verify with sha256 instead:

    unpatched: 897bdeb7f86a77e0...   (0x54c4 = 0x34000614)
    patched:   b2f3c5d6ca9fcd7a...   (0x54c4 = 0x14000030)

The patch is a single 4-byte word and is exactly reversible: writing
0x34000614 back at 0x54c4 reproduces the unpatched hash bit for bit.

## Why

Android 16 removed HIDL gnss entirely. Every framework compatibility matrix
(7, 8, 202404, 202504) lists ONLY:

    <hal format="aidl"><name>android.hardware.gnss</name><version>2-6</version>

so hwservicemanager can never accept an android.hardware.gnss@2.1 registration.
QTI's binary registers BOTH transports and treats the HIDL failure as fatal:

    register IGnss AIDL service success        <- the part the framework wants
    Error while registering IGnss HIDL 2.1 service: 1
    init: Service 'gnss_service' exited with status 1

so the process dies, taking its already-successful AIDL registration with it,
and restarts forever. lshal shows no gnss and LocationManager has no gps
provider. There is no property to disable the HIDL half -- the binary contains
no property strings at all.

Declaring @2.1 in the device manifest does NOT help and additionally hangs the
boot (tested 2026-09-07) -- see the gnss section in PORTING-NOTES.md.

## The patch

At file offset 0x54c4, immediately after the registerPassthroughServiceImplementation
call whose status lands in w20:

    54a4:  bl   registerPassthroughServiceImplementation@plt
    54ac:  mov  w20, w0                       ; w20 = status
    54c4:  cbz  w20, 0x5584                   ; if OK -> success path
    54c8:  ...log "Error while registering IGnss HIDL 2.1 service: %d"...

    before: 34 00 06 14   (0x34000614)  cbz w20, +48  -> 0x5584
    after:  30 00 00 14   (0x14000030)  b        +48  -> 0x5584

i.e. take the success path unconditionally. 0x5584 is the genuine success
continuation (dlGetSymFromLib, an INFO log, then the rest of init), verified by
disassembly. Same displacement, so nothing else moves; file size is unchanged
at 32440 bytes.

## Reapply

    python3 - <<'PY'
    import struct
    p='vendor/sony/pdx246/proprietary/vendor/bin/hw/android.hardware.gnss-aidl-service-qti'
    d=bytearray(open(p,'rb').read())
    old=struct.unpack_from('<I', d, 0x54c4)[0]
    assert old==0x34000614, f"unexpected 0x{old:08x} -- do not patch blindly"
    struct.pack_into('<I', d, 0x54c4, 0x14000000|48)
    open(p,'wb').write(bytes(d))
    PY

## Proper fix

An AIDL-only gnss blob from a 6.6-era device, or Sony/QTI shipping one that
does not hard-depend on HIDL. This patch is a bring-up workaround.

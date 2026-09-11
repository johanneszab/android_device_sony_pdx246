# HISTORICAL: modem remoteproc was temporarily disabled in prebuilts/dtb.img

REVERTED 2026-09-07. prebuilts/dtb.img is now byte-identical to the DTB
embedded in stock's vendor_boot.img (4887468 bytes) and the modem node is in
its stock state again.

## What was done, and why

status = "disabled" was set on /soc/remoteproc-mss@04080000 in all 14 FDTs
(making the file 4887580 bytes). The modem booted, ran ~100 s, then its
internal watchdog reported

    qcom_q6v5_pas 4080000.remoteproc-mss: fatal error received:
      dog_hb.c:370: Task starvation: nv, ping: 4

and qcom_q6v5_crash_handler_work() calls panic() unconditionally -- there is no
module parameter or sysfs control for it, and qcom_q6v5 is one of our prebuilt
.ko files, so it could not be patched. Disabling the node stopped the modem
being brought up at all, which answered "is the modem the only thing still
blocking the boot?". It was always a diagnostic, never a fix.

## Why it is worth retrying NOW

The starvation message names **nv** -- the modem's non-volatile item store.
When that diagnosis was made, `tad` was NOT running: Sony's Trim Area daemon
had no SELinux type declared, so init could not honour its seclabel and the
service never started (see the sepolicy section in PORTING-NOTES.md). The TA
partition is exactly where this device keeps per-unit calibration and modem NV
data, so the modem may well have been starving because nothing was serving it.

As of 2026-09-07 tad, ta_qmi_service and mlog_qmi_service all run, so the
premise behind the workaround no longer holds.

## If the ~100 s panic returns

Re-apply by setting status = "disabled" on /soc/remoteproc-mss@04080000 in all
14 FDTs. Note the build gotcha: --dtb is passed via BOARD_MKBOOTIMG_ARGS and is
NOT a tracked dependency, so
    rm -f out/target/product/pdx246/{boot,vendor_boot}.img
before rebuilding or the old DTB ships silently.
Revert again with: git checkout -- device/sony/pdx246/prebuilts/dtb.img

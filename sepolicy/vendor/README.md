Device sepolicy for pdx246.

file.te.minimal-fallback is the standalone version that declares just the three
types the fstab's context= mount options need (firmware_file, bt_firmware_file,
vendor_qmcs_file, each with contextmount_type). It is NOT active: BoardConfig.mk
now pulls in the full QTI vendor policy from device/qcom/sepolicy_vndr/sm8450,
which declares the same types, so keeping both is a duplicate declaration.

If the QTI policy has to be backed out again, rename this back to file.te --
it is verified to fix the three failing mounts on its own.

tad, ta_qmi_service and mlog_qmi_service (types, rules and labels) come from
hardware/sony/sepolicy/qti, which BoardConfig.mk includes like pdx257 does.
The device copies were removed on 2026-09-12 because they declared the same
types. Only the wait4tad label stays here: that policy does not label it,
stock does (/odm/etc/selinux/odm_file_contexts).

Device sepolicy for pdx246.

file.te.minimal-fallback is the standalone version that declares just the three
types the fstab's context= mount options need (firmware_file, bt_firmware_file,
vendor_qmcs_file, each with contextmount_type). It is NOT active: BoardConfig.mk
now pulls in the full QTI vendor policy from device/qcom/sepolicy_vndr/sm8450,
which declares the same types, so keeping both is a duplicate declaration.

If the QTI policy has to be backed out again, rename this back to file.te --
it is verified to fix the three failing mounts on its own.

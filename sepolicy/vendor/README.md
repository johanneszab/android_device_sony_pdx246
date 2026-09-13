Device sepolicy for pdx246.

sepolicy/vendor holds the device policy: the domains, labels and rules ported
from stock's /odm and /vendor policy, on top of hardware/sony/sepolicy/qti and
the QTI vendor policy that BoardConfig.mk includes. sepolicy/vendor-after-sony
holds statements about types that hardware/sony/sepolicy declares, because
checkpolicy has to read them after that policy.

tad, ta_qmi_service and mlog_qmi_service get their types and labels from
hardware/sony/sepolicy/qti, which BoardConfig.mk includes like pdx257 does;
stock's rules for them are ported here. Only the wait4tad label is declared
here: that policy does not label it, stock does
(/odm/etc/selinux/odm_file_contexts).

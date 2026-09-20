#
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from pdx246 device
$(call inherit-product, device/sony/pdx246/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_pdx246
PRODUCT_DEVICE := pdx246
PRODUCT_MANUFACTURER := Sony
PRODUCT_BRAND := Sony
PRODUCT_MODEL := XQ-ES54

PRODUCT_GMS_CLIENTID_BASE := android-sonymobile

# Stock's own values, from product/etc/build.prop of the
# XQ-ES54_EEA-user 16 70.2.A.4.168 dump the blobs come from:
#   ro.build.description, ro.build.fingerprint, ro.product.device,
#   ro.product.name. The fingerprint's third field is the device
#   (XQ-ES54) and its second is the product (XQ-ES54_EEA); DeviceName
#   and DeviceProduct have to match those, or the props next to the
#   fingerprint disagree with it.
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="XQ-ES54_EEA-user 16 70.2.A.4.168 070002A004016801749288677 release-keys" \
    BuildFingerprint=Sony/XQ-ES54_EEA/XQ-ES54:16/70.2.A.4.168/070002A004016801749288677:user/release-keys \
    DeviceName=XQ-ES54 \
    DeviceProduct=XQ-ES54_EEA \
    SystemDevice=XQ-ES54 \
    SystemName=XQ-ES54_EEA

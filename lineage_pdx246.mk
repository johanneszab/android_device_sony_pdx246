#
# SPDX-FileCopyrightText: The LineageOS Project
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

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="XQ-ES54_EEA-user 16 70.3.A.4.168 070002A004016801749288677 release-keys" \
    BuildFingerprint=Sony/XQ-ES54_EEA/XQ-ES54:14/70.0.A.3.169/070000A003016900523174845:user/release-keys \
    DeviceName=XQ-ES54 \
    DeviceProduct=XQ-ES54 \
    SystemDevice=XQ-ES54 \
    SystemName=XQ-ES54

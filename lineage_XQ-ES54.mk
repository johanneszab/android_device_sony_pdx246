#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from XQ-ES54 device
$(call inherit-product, device/sony/XQ-ES54/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_DEVICE := XQ-ES54
PRODUCT_NAME := lineage_XQ-ES54
PRODUCT_BRAND := Sony
PRODUCT_MODEL := XQ-ES54
PRODUCT_MANUFACTURER := sony

PRODUCT_GMS_CLIENTID_BASE := android-sonymobile

PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="XQ-ES54_EEA-user 16 70.2.A.4.168 070002A004016801749288677 release-keys" \
    BuildFingerprint=Sony/sssi/qssi:16/BQ2A.250525.001-BP2A.250605.031.A3/A16-COLUMBIA-QSSI-260615-1341:user/release-keys

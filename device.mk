#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Add common definitions for Qualcomm
$(call inherit-product, hardware/qcom-caf/common/common.mk)

# Enable updating of APEXes
$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)

# A/B
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_vendor=true \
    POSTINSTALL_PATH_vendor=bin/checkpoint_gc \
    FILESYSTEM_TYPE_vendor=ext4 \
    POSTINSTALL_OPTIONAL_vendor=true

PRODUCT_PACKAGES += \
    checkpoint_gc \
    otapreopt_script

# android.hardware.boot: NOT CURRENTLY PROVIDED.
# The matrix only accepts AIDL, so the HIDL @1.2 service is useless here, but
# QTI's AIDL replacement does not build against our prebuilt kernel headers:
#   libgptutils.qti: bionic/libc/include/sched.h:99: redefinition of
#   'sched_param' (previous definition in the generated kernel headers'
#   linux/sched/types.h)
# It is only needed by update_engine for A/B slot management, not to boot, so
# it is left out. REVISIT before OTAs are expected to work.

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier

# AAPT
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

# API levels
PRODUCT_SHIPPING_API_LEVEL := 34

# Boot animation
TARGET_SCREEN_HEIGHT := 2520
TARGET_SCREEN_WIDTH := 1080

# fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    fastbootd

# Power
# The stock blob implements AIDL power V1, which no framework
# compatibility matrix accepts. Build the QTI HAL, which is V6.
PRODUCT_PACKAGES += \
    android.hardware.power-service-qti

# Mount points
# rootdir/etc/fstab.default mounts modem/dsp/bluetooth firmware and vm-system
# under /vendor. The mount-point directories have to exist in the vendor image
# or the mounts silently fail -- which is why adsprpcd loops on
# "apps_dev_init failed ... No such device" (no DSP firmware) and the firmware
# -dependent HALs abort. Same class of bug as the missing /metadata dir.
PRODUCT_PACKAGES += \
    vendor_bt_firmware_mountpoint \
    vendor_dsp_mountpoint \
    vendor_firmware_mnt_mountpoint \
    vendor_vm-system_mountpoint

# Hardware feature declarations
#
# pdx246 shipped ZERO of these: `find $OUT -path '*etc/permissions/android.hardware.*'`
# returned nothing, while stock declares 41 and device/sony/pdx257 copies 52.
# The framework therefore believed this device had no wifi, bluetooth, nfc,
# camera, sensors, telephony, fingerprint, usb or vulkan.
#
# That is not cosmetic. DisplayManagerService.registerWifiDisplayAdapterLocked()
# throws outright when config_enableWifiDisplay is set (it is, because we ship
# WfdService) and android.hardware.wifi.direct is absent:
#   FATAL EXCEPTION IN SYSTEM PROCESS: android.display
#   java.lang.RuntimeException: WiFi display was requested, but there is no
#     WiFi Direct feature   (WifiDisplayAdapter.java:110)
# which killed system_server at ~997 s.
#
# The list is stock's own declarations, which is the authority on what this
# hardware actually has. Two of stock's 41 are deliberately excluded:
#   - android.hardware.light.xml declares a shared LIBRARY, not a feature, and
#     points at /system/framework/android.hardware.light-V2.0-java.jar, which
#     is not present even in the stock dump.
#   - android.hardware.hardware_keystore.xml has no AOSP source and a
#     device-specific version, so it lives in permissions/ here instead.
#
# Deliberately NOT copied, though stock has them:
#   android.software.freeform_window_management.xml -- pdx257 does not ship it
#     either and it is unrelated to bring-up; revisit if freeform is wanted.
#   android.software.{opengles,vulkan}.deqp.level.xml -- generated per device by
#     the build with a dEQP level value, not static files in AOSP.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.low_latency.xml \
    frameworks/native/data/etc/android.hardware.audio.pro.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.audio.pro.xml \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.concurrent.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.concurrent.xml \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.camera.raw.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.raw.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.hardware.keystore.app_attest_key.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.keystore.app_attest_key.xml \
    frameworks/native/data/etc/android.hardware.location.gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.location.gps.xml \
    frameworks/native/data/etc/android.hardware.nfc.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.ese.xml \
    frameworks/native/data/etc/android.hardware.nfc.hce.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hce.xml \
    frameworks/native/data/etc/android.hardware.nfc.hcef.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.hcef.xml \
    frameworks/native/data/etc/android.hardware.nfc.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.uicc.xml \
    frameworks/native/data/etc/android.hardware.nfc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.ese.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.ese.xml \
    frameworks/native/data/etc/android.hardware.se.omapi.uicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.se.omapi.uicc.xml \
    frameworks/native/data/etc/android.hardware.sensor.accelerometer.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.accelerometer.xml \
    frameworks/native/data/etc/android.hardware.sensor.compass.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.compass.xml \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.proximity.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepcounter.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepcounter.xml \
    frameworks/native/data/etc/android.hardware.sensor.stepdetector.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.stepdetector.xml \
    frameworks/native/data/etc/android.hardware.telephony.euicc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.euicc.xml \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.ims.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute-0.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level-1.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_1.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.software.device_id_attestation.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.device_id_attestation.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml \
    frameworks/native/data/etc/android.software.midi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.midi.xml \
    frameworks/native/data/etc/android.software.verified_boot.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.verified_boot.xml

# Lights -- LineageOS AIDL lights HAL, built from source.
# Replaces the QTI blob, which declared ILights v1 against a v2 framework and
# drove the LCD backlight to 4095 on notification-shade touches. This one
# declares v2 and keeps the RGB notification LED (/sys/class/leds/{red,green,blue}).
PRODUCT_PACKAGES += \
    android.hardware.light-service.lineage

# Audio -- stock HIDL audio@7.0 HAL
#
# frameworks/av/media/libaudiohal/FactoryHal.cpp tries AIDL 1.0 first and then
# falls back to HIDL 7.1 / 7.0 / 6.0, dlopening libaudiohal@<ver>.so. Android 16
# did NOT drop HIDL audio -- DevicesFactoryHalHidl is still built, and this
# device already runs camera on HIDL 2.7, bluetooth on 1.0 and drm on 1.2.
#
# So there is nothing to build here. The HAL, its impl libraries, the whole
# PAL/AGM/AudioReach stack, the mixer paths, card-defs and ACDB calibration are
# all Sony blobs from proprietary-files.txt, and they are the generation that
# matches this ADSP (ACDB SW 1.41.0.0, Aug 2023). What was missing all along was
# vendor/bin/hw/android.hardware.audio.service_64 -- the service that HOSTS the
# @7.0-impl libraries. It is now extracted, together with its .rc.
#
# Deliberately NOT here:
#   com.android.hardware.audio   the AOSP AIDL HAL. If it is present the
#                                framework stops at AIDL and never reaches the
#                                HIDL fallback. It also has no driver for this
#                                codec and returns -ENODEV.
#   audio.{r_submix,usb,bluetooth}.default   AOSP builds these, but Sony ships
#                                them as blobs and the HIDL service dlopens the
#                                blob copies via libhardware.
#
# The QTI AIDL source route is kept in patches/audio/ but is not selected -- its
# AudioReach is a newer generation than this device's ACDB data. See
# PORTING-NOTES.md "AUDIO: THE PREMISE WAS WRONG".

# QTI telephony shared Java libraries, built from source (vendor/codeaurora/telephony).
#
# Four APKs we ship declare <uses-library> on these and throw
# NoClassDefFoundError without them. qcrilmsgtunnel (com.qti.phone) crash-looped
# hard enough to trigger Android Rescue Party, which rebooted the device
# (ro.boot.bootreason = reboot,rescueparty). Dependents:
#   QtiTelephonyService.apk, qcrilmsgtunnel.apk, ims.apk, com.qualcomm.location.apk
#
# Taken from SOURCE rather than as blobs: vendor/codeaurora/telephony provides
# extphonelib, qti-telephony-utils and qti-telephony-hidl-wrapper, and
# vendor/codeaurora/telephony/ims provides ims-ext-common. Extracting the stock
# jars instead collides with those modules:
#   error: overriding commands for target .../product/etc/permissions/ims_ext_common.xml
# This is exactly the list pdx257 uses (device/sony/pdx257/device.mk:337-350).
#
# A shared Java library needs BOTH the jar module and the .xml module -- the XML
# is what maps the <uses-library> name to a file on disk.
PRODUCT_PACKAGES += \
    extphonelib \
    extphonelib-product \
    extphonelib.xml \
    extphonelib_product.xml \
    ims-ext-common \
    ims_ext_common.xml \
    qti-telephony-hidl-wrapper \
    qti-telephony-hidl-wrapper-prd \
    qti_telephony_hidl_wrapper.xml \
    qti_telephony_hidl_wrapper_prd.xml \
    qti-telephony-utils \
    qti-telephony-utils-prd \
    qti_telephony_utils.xml \
    qti_telephony_utils_prd.xml \
    telephony-ext

# Wi-Fi userspace
#
# pdx246 shipped NONE of these. We extract the HIDL wifi HAL blob
# (android.hardware.wifi@1.0-service) and libwifi-hal.so, and with
# libcld80211.so added the driver now probes and creates wlan0 -- but nothing
# ever provided wpa_supplicant, so:
#   SupplicantStaIfaceHal: Failed to get internal ISupplicantStaIfaceHal instance
#   SupplicantP2pIfaceHal: Failed to get internal ISupplicantP2pIfaceHal instance
#   wificond: tearDownClientInterface: erasing wiphy_index for iface_name wlan0
# and wifi could not be enabled at all. wpa_supplicant is what provides
# android.hardware.wifi.supplicant; it is built from external/wpa_supplicant_8.
#
# Mirrors device/sony/pdx257/device.mk, minus android.hardware.wifi-service:
# pdx257 uses the AOSP AIDL wifi service with libwifi-hal-qcom, whereas our
# HIDL blob HAL is already registering IWifi and driving the chip. Revisit that
# split if the HIDL path proves to be a dead end.
# Minimal set on purpose:
#   - wpa_supplicant.conf is ALREADY installed by a blob at
#     /vendor/etc/wifi/wpa_supplicant.conf, and adding the module makes kati
#     fail with "non-existent modules in PRODUCT_PACKAGES".
#   - hostapd (the hotspot) is built without a private driver library, like
#     our wpa_supplicant: BoardConfig.mk sets only BOARD_HOSTAPD_DRIVER, so
#     hostapd compiles its driver commands out. lib_driver_cmd_qcwcn would
#     need the hardware/qcom-caf/wlan soong namespace we deliberately do not
#     import (it collides with our blob libwifi-hal-ctrl -- see the
#     BOARD_USES_QCOM_HARDWARE note). The module brings its AIDL init rc and
#     VINTF fragment, so stock's HIDL hostapd.android.rc is not extracted.
PRODUCT_PACKAGES += \
    hostapd \
    libwifi-hal-ctrl \
    wpa_supplicant

# WLAN firmware symlinks -- see device/sony/pdx246/Android.bp for why.
PRODUCT_PACKAGES += \
    firmware_WCNSS_qcom_cfg.ini_symlink \
    firmware_wlan_mac.bin_symlink

# SoundTrigger
# SystemServer starts SoundTriggerMiddlewareService unconditionally
# (SystemServer.java "StartSoundTriggerMiddlewareService"), and
# DefaultHalFactory.create() falls back to ISoundTriggerHw.getService(true) --
# a HIDL call that retries forever -- whenever the soundtrigger3 AIDL service is
# not declared. With no soundtrigger HAL at all, system_server's main thread
# blocks there and Watchdog panics the device at 66 s, exactly as AudioService
# did before it.
#
# Stock has no standalone soundtrigger service: QTI's audio HAL binary registers
# the interface itself, and we do not use that HAL. AOSP ships the passthrough
# impl (@2.3-impl, which dlopens sound_trigger.primary.$(ro.board.platform).so
# through libhardware -- our extracted sound_trigger.primary.parrot.so) but no
# binderized service, and HIDL Java clients cannot use passthrough. So
# soundtrigger/ provides a small hwbinder wrapper around it.
# HIDL soundtrigger@2.3 is still in framework compatibility_matrix 6/7/8.
PRODUCT_PACKAGES += \
    android.hardware.soundtrigger@2.3-impl \
    android.hardware.soundtrigger@2.3-service.sony

# Sensors
# The multihal binary was shipped as a blob but its init .rc was not, so no
# service ever declared android.hardware.sensors@2.1::ISensors and
# system_server blocked forever in SystemSensorManager.nativeCreate(). AOSP's
# module provides the binary, the .rc and the VINTF fragment together, and
# soong already claims those install paths, so build it rather than extract it.
PRODUCT_PACKAGES += \
    android.hardware.sensors-service.multihal

# vndbinder
# The QTI vendor blobs (rild, the telephony and camera HALs) talk over
# /dev/binderfs/vndbinder, which needs vndservicemanager to be running. Without
# it those services get ENOENT on the vndbinder lookups seen in the boot log.
PRODUCT_PACKAGES += \
    vndservicemanager

# USB
# The QTI gadget HAL reads /vendor/etc/usb_compositions.conf to map a
# composition name (e.g. "adb") onto configfs functions and a VID/PID. Without
# it the gadget is never bound and the device does not enumerate over USB at
# all in Android. vendor/qcom/opensource/usb/hal defines the module; it just
# was never in PRODUCT_PACKAGES. Shipping the stock blob instead collides with
# that module's install rule, so build it from source as pdx257 does.
# Android 16 dropped HIDL usb.gadget: compatibility_matrix.7 lists it as
# format="hidl" version 1.0-2, matrix 8 onwards only has format="aidl". The
# stock @1.2-service-qti blob is HIDL, so hwservicemanager refuses it --
#   getTransport: Cannot find entry android.hardware.usb.gadget@1.2::IUsbGadget
#   Cannot register USB Gadget HAL service
# and adb never enumerates. Build QTI's AIDL services instead (they ship their
# own .rc and VINTF fragments), as pdx257 does.
PRODUCT_PACKAGES += \
    android.hardware.usb-service.qti \
    android.hardware.usb.gadget-service.qti \
    usb_compositions.conf

# Thermal
# The stock android.hardware.thermal@2.0-service.sony blob is HIDL; the matrix
# only accepts AIDL. Build QTI's AIDL thermal service instead.
PRODUCT_PACKAGES += \
    android.hardware.thermal-service.qti

# Vibrator
# vendor/qcom/opensource/vibrator/aidl builds both the impl and the
# service; the stock blob service is not usable against the source impl.
PRODUCT_PACKAGES += \
    vendor.qti.hardware.vibrator.service

# Health
PRODUCT_PACKAGES += \
    android.hardware.health-service.qti

# Kernel
PRODUCT_ENABLE_UFFD_GC := true

# The kernel uses 4K pages (stock reports ro.product.cpu.pagesize.max=4096).
# This has to come from the product variable; setting the property directly in
# product.prop collides with the one the build generates.
PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 4096

# NFC
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/nfc/libnfc-nxp-typef.conf:$(TARGET_COPY_OUT_VENDOR)/etc/libnfc-nxp-typef.conf

# Overlays
PRODUCT_ENFORCE_RRO_TARGETS := *

# SonyPDX246TelephonyRes and SonyPDX246CarrierConfig carry the IMS setup for
# VoLTE and Wi-Fi calling, together with the IMS flags in SonyPDX246FrameworksRes.
PRODUCT_PACKAGES += \
    SonyPDX246SystemUIRes \
    SonyPDX246NfcNciRes \
    SonyPDX246FrameworksRes \
    SonyPDX246TelephonyRes \
    SonyPDX246CarrierConfig

DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay-lineage

# Partitions
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Product characteristics
PRODUCT_CHARACTERISTICS := default

# Rootdir
PRODUCT_PACKAGES += \
    AudioPlayback.sh \
    init.class_main.sh \
    init.crda.sh \
    init.kernel.post_boot-parrot.sh \
    init.kernel.post_boot-ravelin.sh \
    init.kernel.post_boot.sh \
    init.mdm.sh \
    init.qcom.class_core.sh \
    init.qcom.coex.sh \
    init.qcom.early_boot.sh \
    init.qcom.efs.sync.sh \
    init.qcom.post_boot.sh \
    init.qcom.sdio.sh \
    init.qcom.sensors.sh \
    init.qcom.sh \
    init.qcom.usb.sh \
    init.qti.display_boot.sh \
    init.qti.kernel.debug-parrot.sh \
    init.qti.kernel.debug-ravelin.sh \
    init.qti.kernel.debug.sh \
    init.qti.kernel.early_debug-parrot.sh \
    init.qti.kernel.early_debug.sh \
    init.qti.kernel.sh \
    init.qti.media.sh \
    init.qti.qcv.sh \
    init.qti.touch_boot.sh \
    init.qti.write.sh \
    qca6234-service.sh \
    vendor_modprobe.sh \

PRODUCT_PACKAGES += \
    fstab.default \
    fstab.default.vendor_ramdisk \
    init.qcom.factory.rc \
    init.qcom.rc \
    init.qcom.usb.rc \
    init.qti.kernel.rc \
    init.qti.ufs.rc \
    init.target.rc \
    init.recovery.qcom.rc \

# Soong namespaces
# hardware/qcom-caf/{bootctrl,thermal} each declare their own soong_namespace,
# so the AIDL boot and thermal services are invisible without opting in.
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH) \
    hardware/qcom-caf/bootctrl \
    hardware/qcom-caf/thermal

# Inherit the proprietary files
$(call inherit-product, vendor/sony/pdx246/pdx246-vendor.mk)

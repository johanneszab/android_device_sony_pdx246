#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)

from extract_utils.fixups_lib import (
    lib_fixups,
    lib_fixups_user_type,
)

from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'device/sony/pdx246',
    'hardware/qcom-caf/sm8450-6.6',
    'hardware/qcom-caf/wlan',
    'vendor/qcom/opensource/commonsys-intf/display',
    'vendor/qcom/opensource/commonsys/display',
    'vendor/qcom/opensource/dataservices',
]

def c2_store_allocation_fixup(offset: int):
    """Allocate utils::ComponentStore with the size of our libcodec2_hidl.

    The Codec2 services allocate their utils::ComponentStore (libcodec2_hidl)
    themselves, with the size stock's Android 14 headers gave: 0x108 bytes.
    Since 2024 the class has more members (the MultiAccessUnit interface and
    reflector, a vector of param reflectors) and is 0x120 bytes, and the
    constructor in our Android 16 libcodec2_hidl fills all of it. Its virtual
    RefBase base lies at the end, past the allocation, so the next allocation
    there overwrites mRefs and the service crashes in RefBase::decStrong (at
    boot, in _hidl_listComponents), at some boots only. Load 0x120 instead of
    0x108 before the operator new call.
    """
    import struct

    MOV_W0_0X108 = 0x52802100
    MOV_W0_0X120 = 0x52802400

    def fixup(ctx, file, file_path: str, *args, **kwargs):
        with open(file_path, 'rb') as f:
            data = bytearray(f.read())

        current = struct.unpack_from('<I', data, offset)[0]
        if current == MOV_W0_0X120:
            return  # already patched, keep this idempotent

        if current != MOV_W0_0X108:
            raise ValueError(
                f'{file.dst}: expected mov w0, #0x108 (0x{MOV_W0_0X108:08x}) at '
                f'0x{offset:x}, found 0x{current:08x}. The blob changed -- find '
                f'the operator new call before the ComponentStore constructor again.'
            )

        struct.pack_into('<I', data, offset, MOV_W0_0X120)
        with open(file_path, 'wb') as f:
            f.write(bytes(data))

    return fixup


def lib_fixup_vendor_suffix(lib: str, partition: str, *args, **kwargs):
    return f'{lib}_{partition}' if partition == 'vendor' else None


lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
    (
        'libgrpc++_unsecure',
        'libwifi-hal-qcom',
        'com.qualcomm.qti.bluetooth_audio@1.0',
        'com.qualcomm.qti.dpm.api@1.0',
        'com.qualcomm.qti.imscmservice@2.0',
        'com.qualcomm.qti.imscmservice@2.1',
        'com.qualcomm.qti.imscmservice@2.2',
        'com.qualcomm.qti.uceservice@2.0',
        'com.qualcomm.qti.uceservice@2.1',
        'com.qualcomm.qti.uceservice@2.2',
        'com.qualcomm.qti.uceservice@2.3',
        'vendor.display.color@1.0',
        'vendor.display.color@1.1',
        'vendor.display.color@1.2',
        'vendor.display.color@1.3',
        'vendor.display.postproc@1.0',
        'vendor.qti.data.factory@2.0',
        'vendor.qti.data.factory@2.1',
        'vendor.qti.data.factory@2.2',
        'vendor.qti.data.factory@2.3',
        'vendor.qti.data.factory@2.4',
        'vendor.qti.data.factory@2.5',
        'vendor.qti.data.mwqem@1.0',
        'vendor.qti.data.slm@1.0',
        'vendor.qti.diaghal@1.0',
        'vendor.qti.hardware.alarm@1.0',
        'vendor.qti.hardware.data.cne.internal.api@1.0',
        'vendor.qti.hardware.data.cne.internal.constants@1.0',
        'vendor.qti.hardware.data.cne.internal.server@1.0',
        'vendor.qti.hardware.data.cne.internal.server@1.1',
        'vendor.qti.hardware.data.cne.internal.server@1.2',
        'vendor.qti.hardware.data.connection@1.0',
        'vendor.qti.hardware.data.connection@1.1',
        'vendor.qti.hardware.data.dynamicdds@1.0',
        'vendor.qti.hardware.data.dynamicdds@1.1',
        'vendor.qti.hardware.data.flow@1.0',
        'vendor.qti.hardware.data.iwlan@1.0',
        'vendor.qti.hardware.data.iwlan@1.1',
        'vendor.qti.hardware.data.latency@1.0',
        'vendor.qti.hardware.data.lce@1.0',
        'vendor.qti.hardware.data.qmi@1.0',
        'vendor.qti.hardware.dpmservice@1.0',
        'vendor.qti.hardware.dpmservice@1.1',
        'vendor.qti.hardware.embmssl@1.0',
        'vendor.qti.hardware.embmssl@1.1',
        'vendor.qti.hardware.iop@2.0',
        'vendor.qti.hardware.limits@1.0',
        'vendor.qti.hardware.limits@1.1',
        'vendor.qti.hardware.mwqemadapter@1.0',
        'vendor.qti.hardware.qccsyshal@1.0',
        'vendor.qti.hardware.qccsyshal@1.1',
        'vendor.qti.hardware.qdutils_disp@1.0',
        'vendor.qti.hardware.qseecom@1.0',
        'vendor.qti.hardware.qteeconnector@1.0',
        'vendor.qti.hardware.radio.am@1.0',
        'vendor.qti.hardware.radio.ims@1.0',
        'vendor.qti.hardware.radio.ims@1.1',
        'vendor.qti.hardware.radio.ims@1.2',
        'vendor.qti.hardware.radio.ims@1.3',
        'vendor.qti.hardware.radio.ims@1.4',
        'vendor.qti.hardware.radio.ims@1.5',
        'vendor.qti.hardware.radio.ims@1.6',
        'vendor.qti.hardware.radio.ims@1.7',
        'vendor.qti.hardware.radio.ims@1.8',
        'vendor.qti.hardware.radio.internal.deviceinfo@1.0',
        'vendor.qti.hardware.radio.lpa@1.0',
        'vendor.qti.hardware.radio.lpa@1.1',
        'vendor.qti.hardware.radio.lpa@1.2',
        'vendor.qti.hardware.radio.qcrilhook@1.0',
        'vendor.qti.hardware.radio.qtiradio@1.0',
        'vendor.qti.hardware.radio.qtiradio@2.0',
        'vendor.qti.hardware.radio.qtiradio@2.1',
        'vendor.qti.hardware.radio.qtiradio@2.2',
        'vendor.qti.hardware.radio.qtiradio@2.3',
        'vendor.qti.hardware.radio.qtiradio@2.4',
        'vendor.qti.hardware.radio.qtiradio@2.5',
        'vendor.qti.hardware.radio.qtiradio@2.6',
        'vendor.qti.hardware.radio.uim@1.0',
        'vendor.qti.hardware.radio.uim@1.1',
        'vendor.qti.hardware.radio.uim@1.2',
        'vendor.qti.hardware.radio.uim_remote_client@1.0',
        'vendor.qti.hardware.radio.uim_remote_client@1.1',
        'vendor.qti.hardware.radio.uim_remote_client@1.2',
        'vendor.qti.hardware.radio.uim_remote_server@1.0',
        'vendor.qti.hardware.sigma_miracast@1.0',
        'vendor.qti.hardware.slmadapter@1.0',
        'vendor.qti.hardware.trustedui@1.0',
        'vendor.qti.hardware.vpp@1.1',
        'vendor.qti.hardware.wifidisplaysession@1.0',
        'vendor.qti.ims.callcapability@1.0',
        'vendor.qti.ims.callinfo@1.0',
        'vendor.qti.ims.configservice@1.0',
        'vendor.qti.ims.configservice@1.1',
        'vendor.qti.ims.connection@1.0',
        'vendor.qti.ims.factory@1.0',
        'vendor.qti.ims.factory@1.1',
        'vendor.qti.ims.factory@2.0',
        'vendor.qti.ims.factory@2.1',
        'vendor.qti.ims.factory@2.2',
        'vendor.qti.ims.rcsconfig@1.0',
        'vendor.qti.ims.rcsconfig@1.1',
        'vendor.qti.ims.rcsconfig@2.0',
        'vendor.qti.ims.rcsconfig@2.1',
        'vendor.qti.ims.rcssip@1.0',
        'vendor.qti.ims.rcssip@1.1',
        'vendor.qti.ims.rcssip@1.2',
        'vendor.qti.ims.rcsuce@1.0',
        'vendor.qti.ims.rcsuce@1.1',
        'vendor.qti.ims.rcsuce@1.2',
        'vendor.qti.imsrtpservice@3.0',
        'vendor.qti.latency@2.0',
        'vendor.qti.latency@2.1',
        'vendor.qti.qesdhal@1.0',
        'vendor.qti.qesdhal@1.1',
        'vendor.qti.qspmhal@1.0',
    ): lib_fixup_vendor_suffix,
}

blob_fixups: blob_fixups_user_type = {
    ('odm/etc/customization/XQ-ES44/config.prop', 'odm/etc/customization/XQ-ES54_EEA/config.prop', 'odm/etc/customization/XQ-ES72/config.prop'): blob_fixup()
        .regex_replace('vendor', 'odm'),
    # Android switched these libbase overloads to std::string_view; the blobs
    # still reference the std::string ones. hardware/lineage/compat provides
    # both under libbase_shim.
    ('vendor/bin/pnscr',
     'vendor/bin/pnscr_spi',
     'vendor/bin/qguard',
     'vendor/bin/trigger_ffu',
     'vendor/lib/ese_spi_nxp_snxxx.so',
     'vendor/lib/libboot_control_qti.so',
     'vendor/lib64/ese_spi_nxp_snxxx.so',
     'vendor/lib64/libboot_control_qti.so',
     'vendor/lib/nfc_nci_nxp_snxxx.so',
     'vendor/lib64/nfc_nci_nxp_snxxx.so'): blob_fixup()
        .add_needed('libbase_shim.so'),
    ('vendor/bin/poweropt-service', 'vendor/lib64/libdpps.so', 'vendor/lib64/libsnapdragoncolor-manager.so'): blob_fixup()
        .replace_needed('libtinyxml2.so', 'libtinyxml2-v34.so'),
    # Stock links the V2 AIDL types, but the platform libs it sits on top of
    # (libaudioclient/libaudiofoundation) are built against V4, and soong
    # rejects depending on two versions of one aidl_interface.
    ('system_ext/lib/libmiracastsystem.so', 'system_ext/lib64/libmiracastsystem.so'): blob_fixup()
        .replace_needed('android.media.audio.common.types-V2-cpp.so', 'android.media.audio.common.types-V4-cpp.so'),
    # Stock's QCC HAL implementation needs stock's protobuf, which
    # proprietary-files.txt ships renamed next to it.
    'system_ext/lib64/vendor.qti.hardware.qccsyshal@1.2-halimpl.so': blob_fixup()
        .replace_needed('libprotobuf-cpp-full.so', 'libprotobuf-cpp-full-stock.so'),
    # These services declare HIDL interfaces that only exist as blobs, so
    # host_init_verifier (which only knows source-built hidl_interface
    # targets) rejects the scripts. The interface libraries themselves are
    # shipped, so drop the declarations and let the services start normally.
    ('vendor/etc/init/vendor.qti.hardware.wifi.wifilearner@1.0-service.rc',
     'vendor/etc/init/vendor.semc.hardware.display@2.5-service.rc'): blob_fixup()
        .regex_replace(r'(?m)^\s+interface .*\n', ''),
    # The upstream shim only carries the 64-bit mangling of Parcel::setData.
    'vendor/lib64/vendor.libdpmframework.so': blob_fixup()
        .add_needed('libhidlbase_shim.so'),
    'vendor/lib/vendor.libdpmframework.so': blob_fixup()
        .add_needed('libhidlbase_compat32.so'),
    'vendor/etc/wfdconfig.xml': blob_fixup()
        .regex_replace('<M4Enable>0</M4Enable>', '<M4Enable>1</M4Enable>')
        .regex_replace('<UIBCValid>0</UIBCValid>', '<UIBCValid>1</UIBCValid>')
        .regex_replace('<USB>1</USB>', '<USB>3</USB>'),
    # AOSP's Bluetooth stack builds its A2DP offload preference from the
    # encodedFormats of the A2DP output ports. LC3 there has no A2DP codec ID
    # (BluetoothCodecType) and arrives as an invalid codec type, which makes
    # the HIDL UpdateOffloadingCapabilities give up: nothing is offloaded and
    # A2DP media stays silent. CELT, aptX Adaptive and aptX TWS+ are only
    # dropped, with an error log. Keep the five codecs the stack can offload,
    # the list in persist.bluetooth.a2dp_offload.cap. "A2DP In" keeps its LC3.
    ('vendor/etc/audio/sku_parrot/audio_policy_configuration.xml',
     'vendor/etc/audio/sku_parrot_qssi/audio_policy_configuration.xml',
     'vendor/etc/audio/sku_ravelin/audio_policy_configuration.xml',
     'vendor/etc/audio/sku_ravelin_qssi/audio_policy_configuration.xml'): blob_fixup()
        .regex_replace(r'(type="AUDIO_DEVICE_OUT_BLUETOOTH_A2DP\w*"[^>]*encodedFormats=")[^"]*',
                       r'\1AUDIO_FORMAT_SBC AUDIO_FORMAT_AAC AUDIO_FORMAT_APTX '
                       r'AUDIO_FORMAT_APTX_HD AUDIO_FORMAT_LDAC'),
    # The Codec2 HALs run under minijail with these seccomp policies. When a
    # HAL crashes, debuggerd's handler writes the tombstone from inside the
    # process and needs the calls of AOSP's crash_dump policy
    # (system/core/debuggerd/seccomp_policy), which AOSP's media codec
    # policies include. Stock's policies lack the ones below, so the handler
    # was killed at uname(): every crash ended as SIGSYS, without a tombstone.
    ('vendor/etc/seccomp_policy/codec2.vendor.ext-arm64.policy',
     'vendor/etc/seccomp_policy/c2audio.vendor.ext-arm64.policy'): blob_fixup()
        .add_line_if_missing('setsockopt: 1')
        .add_line_if_missing('uname: 1'),
    'vendor/etc/seccomp_policy/vendor.sony.tsr.media.c2-default-seccomp_policy': blob_fixup()
        .add_line_if_missing('recvfrom: 1')
        .add_line_if_missing('setsockopt: 1')
        .add_line_if_missing('sysinfo: 1')
        .add_line_if_missing('uname: 1'),
    # See c2_store_allocation_fixup(): the offset of the mov w0, #0x108 before
    # operator new and the utils::ComponentStore constructor in each service.
    'vendor/bin/hw/vendor.qti.media.c2@1.0-service': blob_fixup()
        .call(c2_store_allocation_fixup(0x2304), need_tmp_dir=False),
    'vendor/bin/hw/vendor.qti.media.c2audio@1.0-service': blob_fixup()
        .call(c2_store_allocation_fixup(0x3e00), need_tmp_dir=False),
    'vendor/bin/hw/vendor.sony.tsr.media.c2-service': blob_fixup()
        .call(c2_store_allocation_fixup(0x10d8), need_tmp_dir=False),
    'vendor/lib64/camera/components/com.arcsoft.node.dual_smooth_transition.so': blob_fixup()
        .add_needed('liblog.so'),
    'vendor/lib64/libarcsoft_high_dynamic_range_v5.so': blob_fixup()
        .clear_symbol_version('remote_register_buf')
        .clear_symbol_version('rpcmem_alloc')
        .clear_symbol_version('rpcmem_free')
        .clear_symbol_version('rpcmem_to_fd'),

    # The stock base still links against the pre-Android 12 "-ndk_platform"
    # AIDL runtime names. Those libraries do not exist any more (not even in
    # the stock dump), so point the blobs at the modern "-ndk" names.
    ('vendor/bin/hw/android.hardware.gnss-aidl-service-qti',
     'vendor/lib/hw/android.hardware.gnss-aidl-impl-qti.so',
     'vendor/lib64/hw/android.hardware.gnss-aidl-impl-qti.so',
     'vendor/lib64/libgarden.so',
     'vendor/lib64/libgarden_haltests_e2e.so'): blob_fixup()
        .replace_needed('android.hardware.gnss-V1-ndk_platform.so', 'android.hardware.gnss-V1-ndk.so'),
    'vendor/bin/hw/android.hardware.secure_element_snxxx@1.2-service': blob_fixup()
        .replace_needed('android.hardware.nfc-V1-ndk_platform.so', 'android.hardware.nfc-V1-ndk.so'),
    'vendor/bin/hw/android.hardware.security.keymint-service-qti': blob_fixup()
        .add_needed('android.hardware.security.rkp-V1-ndk.so')
        .replace_needed('android.hardware.security.keymint-V1-ndk_platform.so', 'android.hardware.security.keymint-V1-ndk.so')
        .replace_needed('android.hardware.security.secureclock-V1-ndk_platform.so', 'android.hardware.security.secureclock-V1-ndk.so')
        .replace_needed('android.hardware.security.sharedsecret-V1-ndk_platform.so', 'android.hardware.security.sharedsecret-V1-ndk.so'),
    ('vendor/lib/libqtikeymint.so', 'vendor/lib64/libqtikeymint.so'): blob_fixup()
        .add_needed('android.hardware.security.rkp-V1-ndk.so')
        .replace_needed('android.hardware.security.keymint-V1-ndk_platform.so', 'android.hardware.security.keymint-V1-ndk.so')
        .replace_needed('android.hardware.security.secureclock-V1-ndk_platform.so', 'android.hardware.security.secureclock-V1-ndk.so')
        .replace_needed('android.hardware.security.sharedsecret-V1-ndk_platform.so', 'android.hardware.security.sharedsecret-V1-ndk.so'),
    ('vendor/bin/hw/vendor.semc.hardware.aidlsecd-service', 'vendor/bin/keyprovd'): blob_fixup()
        .replace_needed('android.hardware.security.keymint-V1-ndk_platform.so', 'android.hardware.security.keymint-V1-ndk.so'),
    ('vendor/bin/hw/vendor.qti.hardware.display.composer-service',
     'vendor/lib/vendor.qti.hardware.display.config-V1-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V2-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V3-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V4-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V5-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V6-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V7-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V8-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V9-ndk_platform.so',
     'vendor/lib/vendor.qti.hardware.display.config-V10-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V1-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V2-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V3-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V4-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V5-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V6-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V7-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V8-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V9-ndk_platform.so',
     'vendor/lib64/vendor.qti.hardware.display.config-V10-ndk_platform.so'): blob_fixup()
        .replace_needed('android.hardware.common-V2-ndk_platform.so', 'android.hardware.common-V2-ndk.so'),
}  # fmt: skip

module = ExtractUtilsModule(
    'pdx246',
    'sony',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
)

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()

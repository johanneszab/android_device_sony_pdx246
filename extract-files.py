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
]

def lib_fixup_vendor_suffix(lib: str, partition: str, *args, **kwargs):
    return f'{lib}_{partition}' if partition == 'vendor' else None

lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
    (
        'vendor.qti.hardware.data.connectionaidl-V1-ndk.so',
        'vendor.qti.diaghal-V1-ndk.so',
        'graphicbuffersource-aidl-ndk.so',
        'libaconfig_storage_read_api_cc.so',
        'libmedia_codeclist.so',
        'libmedia_codeclist_capabilities.so',
        'libstagefright_aidl_bufferpool2.so',
        'libstagefright_codecbase.so',
        'libstagefright_framecapture_utils.so',
        'libstagefright_graphicbuffersource_aidl.so',
        'libstagefright_surface_utils.so',
    ): lib_fixup_vendor_suffix,
}

module = ExtractUtilsModule(
    'pdx246',
    'sony',
)

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()

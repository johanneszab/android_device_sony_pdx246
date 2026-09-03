/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * hardware/lineage/compat's libhidlbase_shim restores
 * android::hardware::Parcel::setData(), but only under the 64-bit mangling
 * (..EPKhm, size_t == unsigned long). pdx246 is a 64+32 device and the 32-bit
 * dpm stack (vendor.libdpmframework and friends) needs the 32-bit mangling
 * (..EPKhj, size_t == unsigned int), so provide that variant here.
 */

#include <hwbinder/Parcel.h>

#include <cstring>

namespace android {
namespace hardware {

extern "C" status_t _ZN7android8hardware6Parcel7setDataEPKhj(Parcel* thisptr,
                                                             const uint8_t* buffer,
                                                             unsigned int len) {
    thisptr->freeData();
    status_t err = thisptr->setDataSize(len);
    if (err == NO_ERROR) {
        memcpy(const_cast<uint8_t*>(thisptr->data()), buffer, len);
    }
    return err;
}

}  // namespace hardware
}  // namespace android

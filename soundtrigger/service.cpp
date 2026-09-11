/*
 * Binderized wrapper for the AOSP soundtrigger@2.3 passthrough implementation.
 *
 * AOSP ships android.hardware.soundtrigger@2.3-impl (a passthrough library that
 * dlopens sound_trigger.primary.<ro.board.platform>.so via libhardware) but no
 * service binary to expose it over hwbinder. Stock pdx246 has no standalone
 * soundtrigger service either -- QTI's audio HAL binary registers the interface
 * itself, and we do not use that HAL.
 *
 * Without a binderized instance, SystemServer hangs: DefaultHalFactory.create()
 * falls back to ISoundTriggerHw.getService(true) when the soundtrigger3 AIDL
 * service is not declared, and that HIDL call retries forever. HIDL Java
 * clients cannot use passthrough, so a real hwbinder service is required.
 */
#define LOG_TAG "android.hardware.soundtrigger@2.3-service.sony"

#include <android/hardware/soundtrigger/2.3/ISoundTriggerHw.h>
#include <hidl/HidlTransportSupport.h>
#include <hidl/LegacySupport.h>
#include <log/log.h>

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::registerPassthroughServiceImplementation;
using android::hardware::soundtrigger::V2_3::ISoundTriggerHw;

int main() {
    configureRpcThreadpool(4, true /* callerWillJoin */);

    android::status_t status = registerPassthroughServiceImplementation<ISoundTriggerHw>();
    if (status != android::OK) {
        ALOGE("Could not register ISoundTriggerHw: %d", status);
        return 1;
    }

    joinRpcThreadpool();
    return 1;  // joinRpcThreadpool should never return
}

/*
 * NOTE: deliberately no vintf_fragments. Sony's extracted
 * /vendor/etc/vintf/manifest/manifest_non_qmaa.xml already declares
 * android.hardware.soundtrigger@2.3::ISoundTriggerHw/default. Adding our own
 * fragment makes checkvintf fail with "Conflicting FqInstance". That existing
 * declaration with nothing registering it is exactly why getService(true) hung.
 */

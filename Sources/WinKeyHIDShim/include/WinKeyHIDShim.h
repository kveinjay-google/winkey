#ifndef WinKeyHIDShim_h
#define WinKeyHIDShim_h

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

// Minimal wrappers around the same private CoreGraphics/IOKit SPI used by
// Scroll Reverser. Keeping the declarations in C avoids fragile Swift imports.

#ifdef __cplusplus
extern "C" {
#endif

CFTypeRef _Nullable WinKeyCGEventCopyIOHIDEvent(CGEventRef _Nonnull event);
double WinKeyIOHIDEventGetFloatValue(CFTypeRef _Nonnull event, uint32_t field);
void WinKeyIOHIDEventSetFloatValue(CFTypeRef _Nonnull event, uint32_t field, double value);
void WinKeyIOHIDEventRelease(CFTypeRef _Nullable event);

uint32_t WinKeyIOHIDEventFieldScrollX(void);
uint32_t WinKeyIOHIDEventFieldScrollY(void);
int WinKeyIOHIDListenEventAccessGranted(void);
void WinKeyIOHIDRequestListenEventAccess(void);

#ifdef __cplusplus
}
#endif

#endif

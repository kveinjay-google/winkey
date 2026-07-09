#include "WinKeyHIDShim.h"

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef double IOHIDFloat;

enum {
    kWinKeyIOHIDEventTypeScroll = 6
};

#define WinKeyIOHIDEventFieldBase(type) ((type) << 16)
#define kWinKeyIOHIDEventFieldScrollBase WinKeyIOHIDEventFieldBase(kWinKeyIOHIDEventTypeScroll)
#define kWinKeyIOHIDEventFieldScrollX (kWinKeyIOHIDEventFieldScrollBase | 0)
#define kWinKeyIOHIDEventFieldScrollY (kWinKeyIOHIDEventFieldScrollBase | 1)

extern IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef event);
extern IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, uint32_t field);
extern void IOHIDEventSetFloatValue(IOHIDEventRef event, uint32_t field, IOHIDFloat value);

CFTypeRef WinKeyCGEventCopyIOHIDEvent(CGEventRef event)
{
    return (CFTypeRef)CGEventCopyIOHIDEvent(event);
}

double WinKeyIOHIDEventGetFloatValue(CFTypeRef event, uint32_t field)
{
    return (double)IOHIDEventGetFloatValue((IOHIDEventRef)event, field);
}

void WinKeyIOHIDEventSetFloatValue(CFTypeRef event, uint32_t field, double value)
{
    IOHIDEventSetFloatValue((IOHIDEventRef)event, field, (IOHIDFloat)value);
}

void WinKeyIOHIDEventRelease(CFTypeRef event)
{
    if (event) {
        CFRelease(event);
    }
}

uint32_t WinKeyIOHIDEventFieldScrollX(void)
{
    return kWinKeyIOHIDEventFieldScrollX;
}

uint32_t WinKeyIOHIDEventFieldScrollY(void)
{
    return kWinKeyIOHIDEventFieldScrollY;
}

#import "WinKeyScrollReverser.h"

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <mach/mach_time.h>
#import "WinKeyHIDShim.h"

typedef NS_ENUM(NSUInteger, WinKeyScrollSource) {
    WinKeyScrollSourceMouse = 0,
    WinKeyScrollSourceTrackpad
};

typedef NS_ENUM(NSUInteger, WinKeyScrollPhase) {
    WinKeyScrollPhaseStart = 0,
    WinKeyScrollPhaseNormal,
    WinKeyScrollPhaseMomentum,
    WinKeyScrollPhaseEnd
};

static uint64_t const WinKeyMillisecond = 1000000;
static NSInteger const WinKeyDiscreteScrollStepSize = 3;
static int64_t const WinKeySyntheticScrollMarker = 0x57494E4B5343524C;

@interface WinKeyScrollReverser ()

@property (nonatomic) CFMachPortRef activeTapPort;
@property (nonatomic) CFRunLoopSourceRef activeTapSource;
@property (nonatomic) CFMachPortRef passiveTapPort;
@property (nonatomic) CFRunLoopSourceRef passiveTapSource;
@property (nonatomic) NSUInteger touching;
@property (nonatomic) uint64_t lastTouchTime;
@property (nonatomic) WinKeyScrollSource lastSource;
@property (nonatomic) BOOL didLogFirstScrollReversal;
@property (nonatomic, readwrite) NSUInteger scrollEventCount;
@property (nonatomic, readwrite) NSUInteger synthesizedScrollEventCount;
@property (nonatomic, copy, readwrite) NSString *lastDebugSummary;

- (void)enableTap;

@end

static uint64_t WinKeyNanoseconds(void)
{
    static mach_timebase_info_data_t info = {0};
    if (info.denom == 0) {
        mach_timebase_info(&info);
    }

    uint64_t time = mach_absolute_time();
    time *= info.numer;
    time /= info.denom;
    return time;
}

static WinKeyScrollPhase WinKeyMomentumPhaseForEvent(CGEventRef eventRef)
{
    switch ([[NSEvent eventWithCGEvent:eventRef] momentumPhase]) {
        case NSEventPhaseBegan:
            return WinKeyScrollPhaseStart;
        case NSEventPhaseStationary:
            return WinKeyScrollPhaseMomentum;
        case NSEventPhaseEnded:
        case NSEventPhaseCancelled:
            return WinKeyScrollPhaseEnd;
        default:
            return WinKeyScrollPhaseNormal;
    }
}

static int32_t WinKeySyntheticLineValue(int64_t delta, int64_t pointDelta, double fixedDelta, NSInteger multiplier)
{
    if (delta != 0) {
        return (int32_t)(delta * multiplier);
    }

    if (pointDelta != 0) {
        return (int32_t)((pointDelta > 0 ? 1 : -1) * multiplier);
    }

    if (fixedDelta != 0) {
        return (int32_t)((fixedDelta > 0 ? 1 : -1) * multiplier);
    }

    return 0;
}

static BOOL WinKeyPostSyntheticScrollEvent(int32_t vertical, int32_t horizontal)
{
    if (vertical == 0 && horizontal == 0) {
        return NO;
    }

    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!source) {
        return NO;
    }

    CGEventRef event = CGEventCreateScrollWheelEvent(
        source,
        kCGScrollEventUnitLine,
        2,
        vertical,
        horizontal
    );
    CFRelease(source);

    if (!event) {
        return NO;
    }

    CGEventSetIntegerValueField(event, kCGEventSourceUserData, WinKeySyntheticScrollMarker);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
    return YES;
}

static CGEventRef WinKeyScrollCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef eventRef, void *userInfo)
{
    @autoreleasepool {
        WinKeyScrollReverser *tap = (__bridge WinKeyScrollReverser *)userInfo;
        uint64_t time = WinKeyNanoseconds();
        NSEvent *event = [NSEvent eventWithCGEvent:eventRef];

        if (type == (CGEventType)NSEventTypeGesture) {
            NSUInteger touching = [[event touchesMatchingPhase:NSTouchPhaseTouching inView:nil] count];
            if (touching >= 2) {
                tap.lastTouchTime = time;
                tap.touching = MAX(tap.touching, touching);
            }
            return eventRef;
        }

        if (type == (CGEventType)NSEventTypeScrollWheel) {
            if (CGEventGetIntegerValueField(eventRef, kCGEventSourceUserData) == WinKeySyntheticScrollMarker) {
                return eventRef;
            }

            if (!tap.enabled) {
                return eventRef;
            }

            BOOL continuous = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventIsContinuous) != 0;
            int64_t axis1 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1);
            int64_t axis2 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis2);
            int64_t pointAxis1 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1);
            int64_t pointAxis2 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis2);
            double fixedAxis1 = CGEventGetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1);
            double fixedAxis2 = CGEventGetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis2);
            CFTypeRef ioHIDEvent = WinKeyCGEventCopyIOHIDEvent(eventRef);

            uint64_t touchElapsed = time - tap.lastTouchTime;
            NSUInteger touching = tap.touching;
            tap.touching = 0;
            WinKeyScrollPhase phase = WinKeyMomentumPhaseForEvent(eventRef);
            WinKeyScrollSource source = tap.lastSource;

            if (!continuous) {
                source = WinKeyScrollSourceMouse;
            } else if (touching >= 2 && touchElapsed < (WinKeyMillisecond * 222)) {
                source = WinKeyScrollSourceTrackpad;
            } else if (phase == WinKeyScrollPhaseNormal && touchElapsed > (WinKeyMillisecond * 333)) {
                source = WinKeyScrollSourceMouse;
            }
            tap.lastSource = source;

            BOOL discreteAdjust = !continuous && llabs(axis1) == 1;
            NSInteger verticalMultiplier = discreteAdjust ? -WinKeyDiscreteScrollStepSize : -1;
            NSInteger horizontalMultiplier = -1;
            tap.scrollEventCount += 1;
            tap.lastDebugSummary = [NSString stringWithFormat:@"events=%lu synthetic=%lu continuous=%@ y=%lld yPt=%lld yFp=%.2f x=%lld xPt=%lld xFp=%.2f",
                                    (unsigned long)tap.scrollEventCount,
                                    (unsigned long)tap.synthesizedScrollEventCount,
                                    continuous ? @"yes" : @"no",
                                    axis1,
                                    pointAxis1,
                                    fixedAxis1,
                                    axis2,
                                    pointAxis2,
                                    fixedAxis2];

            if (!tap.didLogFirstScrollReversal) {
                tap.didLogFirstScrollReversal = YES;
                NSLog(@"WinKey ObjC reversing scroll event: continuous=%@ source=%lu y=%lld y_pt=%lld y_fp=%f x=%lld x_pt=%lld x_fp=%f hid=%@",
                      continuous ? @"true" : @"false",
                      (unsigned long)source,
                      axis1,
                      pointAxis1,
                      fixedAxis1,
                      axis2,
                      pointAxis2,
                      fixedAxis2,
                      ioHIDEvent ? @"true" : @"false");
            }

            if (!continuous) {
                int32_t vertical = WinKeySyntheticLineValue(axis1, pointAxis1, fixedAxis1, verticalMultiplier);
                int32_t horizontal = WinKeySyntheticLineValue(axis2, pointAxis2, fixedAxis2, horizontalMultiplier);
                if (tap.invertSyntheticScrollSign) {
                    vertical = -vertical;
                    horizontal = -horizontal;
                }

                if (WinKeyPostSyntheticScrollEvent(vertical, horizontal)) {
                    tap.synthesizedScrollEventCount += 1;
                    tap.lastDebugSummary = [NSString stringWithFormat:@"events=%lu synthetic=%lu fallback=yes yOut=%d xOut=%d",
                                            (unsigned long)tap.scrollEventCount,
                                            (unsigned long)tap.synthesizedScrollEventCount,
                                            vertical,
                                            horizontal];
                    if (ioHIDEvent) {
                        WinKeyIOHIDEventRelease(ioHIDEvent);
                    }
                    return NULL;
                }
            }

            if (axis1 != 0 || pointAxis1 != 0 || fixedAxis1 != 0) {
                if (axis1 != 0) {
                    CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1, axis1 * verticalMultiplier);
                }

                if (!discreteAdjust) {
                    CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1, fixedAxis1 * verticalMultiplier);
                    CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1, pointAxis1 * verticalMultiplier);

                    if (ioHIDEvent) {
                        double value = WinKeyIOHIDEventGetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollY());
                        WinKeyIOHIDEventSetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollY(), value * verticalMultiplier);
                    }
                }
            }

            if (axis2 != 0 || pointAxis2 != 0 || fixedAxis2 != 0) {
                if (axis2 != 0) {
                    CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis2, axis2 * horizontalMultiplier);
                }
                CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis2, fixedAxis2 * horizontalMultiplier);
                CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis2, pointAxis2 * horizontalMultiplier);

                if (ioHIDEvent) {
                    double value = WinKeyIOHIDEventGetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollX());
                    WinKeyIOHIDEventSetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollX(), value * horizontalMultiplier);
                }
            }

            if (ioHIDEvent) {
                WinKeyIOHIDEventRelease(ioHIDEvent);
            }
        } else {
            [tap enableTap];
        }
    }

    return eventRef;
}

@implementation WinKeyScrollReverser

- (BOOL)isActive
{
    return self.activeTapSource && self.passiveTapSource && self.activeTapPort && self.passiveTapPort;
}

- (void)start
{
    if (self.active) {
        return;
    }

    self.touching = 0;
    self.lastTouchTime = 0;
    self.lastSource = WinKeyScrollSourceMouse;
    self.didLogFirstScrollReversal = NO;
    self.scrollEventCount = 0;
    self.synthesizedScrollEventCount = 0;
    self.lastDebugSummary = @"No scroll events yet";

    self.passiveTapPort = CGEventTapCreate(
        kCGSessionEventTap,
        kCGTailAppendEventTap,
        kCGEventTapOptionListenOnly,
        NSEventMaskGesture,
        WinKeyScrollCallback,
        (__bridge void *)self
    );

    self.activeTapPort = CGEventTapCreate(
        kCGSessionEventTap,
        kCGTailAppendEventTap,
        kCGEventTapOptionDefault,
        NSEventMaskScrollWheel,
        WinKeyScrollCallback,
        (__bridge void *)self
    );

    if (self.passiveTapPort && self.activeTapPort) {
        self.passiveTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.passiveTapPort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), self.passiveTapSource, kCFRunLoopCommonModes);
        self.activeTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.activeTapPort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), self.activeTapSource, kCFRunLoopCommonModes);
        CGEventTapEnable(self.passiveTapPort, YES);
        CGEventTapEnable(self.activeTapPort, YES);
        NSLog(@"WinKey ObjC scroll taps started");
    } else {
        NSLog(@"WinKey ObjC failed to create scroll taps: passive=%p active=%p", self.passiveTapPort, self.activeTapPort);
        [self stop];
    }
}

- (void)stop
{
    if (self.activeTapSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), self.activeTapSource, kCFRunLoopCommonModes);
        CFRelease(self.activeTapSource);
        self.activeTapSource = nil;
    }

    if (self.activeTapPort) {
        CFMachPortInvalidate(self.activeTapPort);
        CFRelease(self.activeTapPort);
        self.activeTapPort = nil;
    }

    if (self.passiveTapSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), self.passiveTapSource, kCFRunLoopCommonModes);
        CFRelease(self.passiveTapSource);
        self.passiveTapSource = nil;
    }

    if (self.passiveTapPort) {
        CFMachPortInvalidate(self.passiveTapPort);
        CFRelease(self.passiveTapPort);
        self.passiveTapPort = nil;
    }
}

- (void)restart
{
    [self stop];
    [self start];
}

- (void)enableTap
{
    if (self.activeTapPort && !CGEventTapIsEnabled(self.activeTapPort)) {
        CGEventTapEnable(self.activeTapPort, YES);
    }
    if (self.passiveTapPort && !CGEventTapIsEnabled(self.passiveTapPort)) {
        CGEventTapEnable(self.passiveTapPort, YES);
    }
}

- (void)dealloc
{
    [self stop];
}

@end

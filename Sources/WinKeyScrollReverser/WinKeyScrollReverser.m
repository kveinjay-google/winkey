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
static NSString *const WinKeyDefaultsScrollActive = @"scrollDebugActive";
static NSString *const WinKeyDefaultsScrollEvents = @"scrollDebugEvents";
static NSString *const WinKeyDefaultsScrollSummary = @"scrollDebugSummary";
static NSString *const WinKeyDefaultsLegacySyntheticEvents = @"scrollDebugSyntheticEvents";

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

static void WinKeyWriteScrollDiagnostics(WinKeyScrollReverser *tap)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:tap.active forKey:WinKeyDefaultsScrollActive];
    [defaults setInteger:(NSInteger)tap.scrollEventCount forKey:WinKeyDefaultsScrollEvents];
    [defaults removeObjectForKey:WinKeyDefaultsLegacySyntheticEvents];
    [defaults setObject:tap.lastDebugSummary ?: @"" forKey:WinKeyDefaultsScrollSummary];
    [defaults synchronize];
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
            double ioHIDAxis1 = 0;
            double ioHIDAxis2 = 0;

            if (ioHIDEvent) {
                ioHIDAxis1 = WinKeyIOHIDEventGetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollY());
                ioHIDAxis2 = WinKeyIOHIDEventGetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollX());
            }

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
            tap.lastDebugSummary = [NSString stringWithFormat:@"events=%lu continuous=%@ y=%lld yPt=%lld yFp=%.2f yHID=%.2f x=%lld xPt=%lld xFp=%.2f xHID=%.2f",
                                    (unsigned long)tap.scrollEventCount,
                                    continuous ? @"yes" : @"no",
                                    axis1,
                                    pointAxis1,
                                    fixedAxis1,
                                    ioHIDAxis1,
                                    axis2,
                                    pointAxis2,
                                    fixedAxis2,
                                    ioHIDAxis2];
            WinKeyWriteScrollDiagnostics(tap);

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

            if (axis1 != 0 || pointAxis1 != 0 || fixedAxis1 != 0) {
                if (axis1 != 0) {
                    CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1, axis1 * verticalMultiplier);
                }

                if (!discreteAdjust) {
                    CGEventSetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1, fixedAxis1 * verticalMultiplier);
                    CGEventSetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1, pointAxis1 * verticalMultiplier);

                    if (ioHIDEvent) {
                        WinKeyIOHIDEventSetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollY(), ioHIDAxis1 * verticalMultiplier);
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
                    WinKeyIOHIDEventSetFloatValue(ioHIDEvent, WinKeyIOHIDEventFieldScrollX(), ioHIDAxis2 * horizontalMultiplier);
                }
            }

            int64_t outAxis1 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis1);
            int64_t outAxis2 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventDeltaAxis2);
            int64_t outPointAxis1 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis1);
            int64_t outPointAxis2 = CGEventGetIntegerValueField(eventRef, kCGScrollWheelEventPointDeltaAxis2);
            double outFixedAxis1 = CGEventGetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis1);
            double outFixedAxis2 = CGEventGetDoubleValueField(eventRef, kCGScrollWheelEventFixedPtDeltaAxis2);
            tap.lastDebugSummary = [NSString stringWithFormat:@"events=%lu mutated=yes continuous=%@ y=%lld->%lld yPt=%lld->%lld yFp=%.2f->%.2f x=%lld->%lld xPt=%lld->%lld xFp=%.2f->%.2f hid=%@",
                                    (unsigned long)tap.scrollEventCount,
                                    continuous ? @"yes" : @"no",
                                    axis1,
                                    outAxis1,
                                    pointAxis1,
                                    outPointAxis1,
                                    fixedAxis1,
                                    outFixedAxis1,
                                    axis2,
                                    outAxis2,
                                    pointAxis2,
                                    outPointAxis2,
                                    fixedAxis2,
                                    outFixedAxis2,
                                    ioHIDEvent ? @"yes" : @"no"];
            WinKeyWriteScrollDiagnostics(tap);

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
    return self.activeTapSource && self.activeTapPort;
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

    if (self.activeTapPort) {
        if (self.passiveTapPort) {
            self.passiveTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.passiveTapPort, 0);
            CFRunLoopAddSource(CFRunLoopGetMain(), self.passiveTapSource, kCFRunLoopCommonModes);
            CGEventTapEnable(self.passiveTapPort, YES);
        }

        self.activeTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.activeTapPort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), self.activeTapSource, kCFRunLoopCommonModes);
        CGEventTapEnable(self.activeTapPort, YES);
        self.lastDebugSummary = self.passiveTapPort ? @"Scroll tap ready; gesture tap ready" : @"Scroll tap ready; gesture tap unavailable";
        WinKeyWriteScrollDiagnostics(self);
        NSLog(@"WinKey ObjC scroll tap started; passive gesture tap %@", self.passiveTapPort ? @"started" : @"unavailable");
    } else {
        self.lastDebugSummary = @"Scroll tap unavailable";
        WinKeyWriteScrollDiagnostics(self);
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

    self.lastDebugSummary = @"Scroll tap stopped";
    WinKeyWriteScrollDiagnostics(self);
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

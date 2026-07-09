#ifndef WinKeyScrollReverser_h
#define WinKeyScrollReverser_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WinKeyScrollReverser : NSObject

@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, getter=isActive) BOOL active;
@property (nonatomic, readonly) NSUInteger scrollEventCount;
@property (nonatomic, copy, readonly) NSString *lastDebugSummary;

- (void)start;
- (void)stop;
- (void)restart;

@end

NS_ASSUME_NONNULL_END

#endif

//
//  ReachabilityManager.m
//  PRXMedia
//
//  Created by Rebecca Nesson on 3/8/13.
//
//


#import "ReachabilityManager.h"
#import "Reachability.h"

@interface ReachabilityManager ()
@property NetworkStatus previousReachability;
@end

@implementation ReachabilityManager

- (id) init {
    self = [super init];
    // if (self) {
    //     [[NSNotificationCenter defaultCenter] addObserver:self
    //                                             selector:@selector(reachabilityDidChange:)
    //                                             name:kReachabilityChangedNotification
    //                                             object:nil];
    //     self.previousReachability = -1;
    // }
    return self;
}

- (void) reachabilityDidChange:(NSNotification *)notification {
    NSLog(@"reachabilityDidChange!");

    CDVReachability * r = [notification object];
    NetworkStatus ns = [r currentReachabilityStatus];

    if (self.delegate && [self.delegate respondsToSelector:@selector(reachabilityDidChangeFrom:to:)]) {
        [self.delegate reachabilityDidChangeFrom:self.previousReachability to:ns];
    }
    self.previousReachability = ns;
}

@end

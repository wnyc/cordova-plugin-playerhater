//
//  ReachabilityManager.h
//  PRXMedia
//
//  Created by Rebecca Nesson on 3/8/13.
//
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

@protocol ReachabilityManagerDelegate;

@interface ReachabilityManager : NSObject

@property (weak) NSObject<ReachabilityManagerDelegate> *delegate;
@property (strong) Reachability *reach;

@end

@protocol ReachabilityManagerDelegate <NSObject>

- (void) reachabilityDidChangeFrom:(NetworkStatus)oldReachability to:(NetworkStatus)newReachability;

@end

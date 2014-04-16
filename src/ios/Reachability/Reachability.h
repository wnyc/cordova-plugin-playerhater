//
//  Reachability.h
//  NYPRNative
//
//  Created by Brad Kammin on 4/30/13.
//
//

#import <Cordova/CDV.h>
#import "CDVReachability.h"

@interface Reachability : NSObject
{    
    CDVReachability     * reach;
}

@property (nonatomic, retain)   CDVReachability      * reach;
@property (nonatomic, assign) BOOL reachableOnWWAN;

-(Reachability*) initWithCDVReachability:(CDVReachability*)reacability;

-(BOOL) isReachable;
-(BOOL) reachableOnWWAN;

-(BOOL)startNotifier;
-(void)stopNotifier;

-(NetworkStatus)currentReachabilityStatus;

+(Reachability*)reachabilityForInternetConnection;

@end

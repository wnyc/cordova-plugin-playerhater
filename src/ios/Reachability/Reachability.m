//
//  Reachability.m
//  NYPRNative
//
//  Created by Brad Kammin on 4/30/13.
//
//

#import "Reachability.h"

@implementation Reachability
@synthesize reach;

-(Reachability*) initWithCDVReachability:(CDVReachability*)reachability{
    self = [super init];
    
    reach = reachability;
    
    return self;
}

-(BOOL) isReachable{
    return [reach currentReachabilityStatus] != NotReachable;
}

-(BOOL) reachableOnWWAN{
    return YES; // for now, disregard this preference by allowing reachability on WWAN
}


+(Reachability *)reachabilityForInternetConnection
{
    CDVReachability * cdvr = [CDVReachability reachabilityForInternetConnection];
    
    Reachability * r = [[Reachability alloc]initWithCDVReachability:cdvr];
    
    return r;
}

-(BOOL)startNotifier
{
    return [reach startNotifier];
}

-(void)stopNotifier
{
    [reach stopNotifier];
}

-(NetworkStatus)currentReachabilityStatus
{
    return [reach currentReachabilityStatus];
}

@end

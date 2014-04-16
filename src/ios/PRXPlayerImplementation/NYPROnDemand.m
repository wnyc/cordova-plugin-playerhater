#import "NYPROnDemand.h"

@implementation NYPROnDemand
@synthesize url;

# pragma mark -- PRXPlayable Interface

- (NSURL *) audioURL {
    if ([self url] == nil){
        // edge condition - a nil value shouldn't make it this far
        return [NSURL fileURLWithPath:@""];
    } else if (isRemote){
        return [NSURL URLWithString:[self url]];
    } else {
        return [NSURL fileURLWithPath:[self url]];
    }
}

- (BOOL) isEqualToPlayable:(id<PRXPlayable>)playable {
    return [playable.audioURL.absoluteString isEqualToString:self.audioURL.absoluteString]; 
}

- (BOOL) isStream
{
    return NO;
}

- (NYPROnDemand*)initWithURL:(NSString *)newurl position:(int)position{
    url=newurl;
    isRemote=true;
    if (position >= 0) {
        _playbackCursorPosition = position;
    }
    return self;
}

- (NYPROnDemand*)initWithFile:(NSString *)file position:(int)position{
    url=file;
    isRemote=false;
    if (position >= 0) {
        _playbackCursorPosition = position;
    }
    return self;
}

- (NSDictionary *) mediaItemProperties {
    return [NSDictionary dictionary];
}

- (NSDictionary *) userInfo {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"test episode title", @"title", nil];
}

@end

  
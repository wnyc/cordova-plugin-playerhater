#import "NYPRStream.h"
@implementation NYPRStream
@synthesize stream_url;

# pragma mark - PRXPlayable Interface

- (NSURL *) audioURL {
    return [NSURL URLWithString:self.stream_url];
}

- (NYPRStream*)initWithURL:(NSString *)url{
    stream_url=url;
    return self;
}

- (NSDictionary *) mediaItemProperties {
    return [NSDictionary dictionary];
}

- (BOOL) isEqualToPlayable:(id<PRXPlayable>)playable {
    return [playable.audioURL.absoluteString isEqualToString:self.audioURL.absoluteString];
}

- (NSDictionary *) userInfo {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"test stream title", @"title", nil];
}

- (BOOL) isStream {
    return YES;
}

@end

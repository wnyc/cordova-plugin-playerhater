#import <Foundation/Foundation.h>
#import "PRXPlayer.h"

@interface NYPRStream : NSObject<PRXPlayable> {
  NSString *stream_url;
}

@property (nonatomic, strong) NSString *stream_url; 

- (NYPRStream*)initWithURL:(NSString *)url;

@end

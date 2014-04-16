#import <Foundation/Foundation.h>
#import "PRXPlayer.h"

@interface NYPROnDemand : NSObject<PRXPlayable> {

    NSString * url;
    BOOL isRemote;
    
    //NSTimeInterval playbackCursorPosition;
}

@property (nonatomic, strong) NSString * url;
@property (nonatomic) NSTimeInterval playbackCursorPosition;

- (NYPROnDemand*)initWithURL:(NSString *)url position:(int)position;
- (NYPROnDemand*)initWithFile:(NSString *)file position:(int)position;

@end


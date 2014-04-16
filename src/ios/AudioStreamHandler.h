//
//  AudioStreamHandler.h
//  NYPRNativeFeatures
//
//  Created by Brad Kammin on 11/16/12.
//
//

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#import <MediaPlayer/MPMediaItem.h>

#import "PRXPlayer.h"
#import "NYPRPlayer.h"

@class NYPRPlayer;

@interface AudioStreamHandler : NSObject<PRXPlayerObserver, NYPRPlayerObserver>
{
    NSString            * mFile;
    int                 mLastKnownState;
    NYPRPlayer          * mPRXBasePlayer;
    id<PRXPlayable>     mCurrentlyPlaying;
    CDVReachability     * mNetworkStatus;
}

@property (nonatomic, retain)   NYPRPlayer  * mPRXBasePlayer;
@property (nonatomic, retain)   CDVReachability      * mNetworkStatus;

- (AudioStreamHandler*) initWithCDVReachability:(CDVReachability*)reachability;

- (BOOL)startPlayingStream:(NSString*)streamFile;
- (BOOL)startPlayingLocalFile:(NSString*)file position:(int)position;
- (BOOL)startPlayingRemoteFile:(NSString*)file position:(int)position;
- (void)stopPlaying;
- (void)pausePlaying;
- (void)unpausePlaying;
- (void)getAudioState;

- (void)seekInterval:(NSInteger) interval;
- (void)seekTo:(NSInteger) position;

- (void)setAudioInfo:(NSString*)title artist:(NSString*)artist artwork:(NSString*)artwork;

@end

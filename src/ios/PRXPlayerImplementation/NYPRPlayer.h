#import <MediaPlayer/MPMediaItem.h>
#import "PRXPlayer.h"

@protocol NYPRPlayerObserver;

@interface NYPRPlayer : PRXPlayer {
    id <NYPRPlayerObserver> mNYPRPlayerObserver;
    
    CDVReachability     * mNetworkStatus;
    
    NSString            * mLockScreenTitle;
    NSString            * mLockScreenDescription;
    NSString            * mLockScreenUrl;
    MPMediaItemArtwork  * mLockScreenArt;
    NSNumber            * mLockScreenDuration;
}

@property (nonatomic, retain)   CDVReachability      * mNetworkStatus;

- (NYPRPlayer*) initWithCDVReachability:(CDVReachability*)reachability;

- (BOOL) isPlayingAtPositiveRate;
- (BOOL) isBuffering;
- (BOOL) isPaused;

- (void) skipBack:(NSTimeInterval)interval;
- (void) skipForward:(NSTimeInterval)interval;
- (void) skipTo:(NSTimeInterval)interval;

- (void)setAudioInfo:(NSString*)title artist:(NSString*)artist artwork:(NSString*)artwork;

- (void) setObserver:(id<NYPRPlayerObserver>)observer;

- (NSTimeInterval) availableDuration;

- (void) refreshMetadata;

@end


@protocol NYPRPlayerObserver <NSObject>
@optional
- (void) observedNYPRPlayerDidCompleteFile;
- (void) observedNYPRPlayerDidStop;
- (void) observedNYPRPlayerDidStart;
- (void) observedNYPRPlayerDidPause;
@end


//
//  PRXPlayer_private.h
//  PRXPlayer
//
//  Copyright (c) 2013 PRX.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "PRXPlayer.h"
#import "ReachabilityManager.h"
#import <MediaPlayer/MediaPlayer.h>

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue); 

@interface PRXPlayer ()

extern float LongPeriodicTimeObserver;

@property (nonatomic, strong) AVURLAsset *currentURLAsset;
@property (nonatomic, strong) AVPlayerItem *currentPlayerItem;

- (void) didLoadTracksForAsset:(AVURLAsset *)asset;
- (void) failedToLoadTracksForAsset:(AVURLAsset *)asset;

@property (nonatomic, readonly) float rateForFilePlayback;
@property (nonatomic, readonly) float rateForPlayback;

@property (nonatomic, readonly) float softEndBoundaryProgress; // between 0.0 and 1.0

@property (nonatomic, strong, readonly) ReachabilityManager *reachManager;
@property (nonatomic, readonly) BOOL allowsPlaybackViaWWAN;
@property (nonatomic, readonly) NSTimeInterval interruptResumeTimeLimit; 

@property (nonatomic, readonly) NSUInteger retryLimit;

@property BOOL manageSession; 

- (BOOL) playable:(id<PRXPlayable>)playable isEqualToPlayable:(id<PRXPlayable>)otherPlayable;

- (void) loadAndPlayPlayable:(id<PRXPlayable>)playable;
- (void) preparePlayable:(id<PRXPlayable>)playable;

- (void) currentPlayableWillChange;
- (void) playerStatusDidChange:(NSDictionary*)change;
- (void) playerRateDidChange:(NSDictionary*)change;
- (void) playerErrorDidChange:(NSDictionary*)change;
- (void) playerItemStatusDidChange:(NSDictionary*)change;
- (void) playerItemBufferEmptied:(NSDictionary*)change;
- (void) playerPeriodicTimeObserverAction;
- (void) playerLongPeriodicTimeObserverAction;
- (void) playerSoftEndBoundaryTimeObserverAction;
- (void) playerItemDidPlayToEndTime:(NSNotification*)notification;
- (void) playerItemDidJumpTime:(NSNotification*)notification;

- (void) beginBackgroundKeepAlive;
- (void) keepAliveInBackground;
- (void) endBackgroundKeepAlive;

- (void) audioSessionDidBeginInterruption:(NSNotification*)notification;
- (void) audioSessionDidEndInterruption:(NSNotification*)notification;
- (void) audioSessionInterruption:(NSNotification*)notification;

- (void) handleAudioSessionRouteChange:(AudioSessionPropertyID)inPropertyID withPropertySize:(UInt32)inPropertyValueSize andValue:(const void *)inPropertyValue;
- (void) audioSessionRouteChange:(NSNotification*)notification;

- (void) observePlayer:(AVPlayer*)player;
- (void) stopObservingPlayer:(AVPlayer*)player;

- (void) observePlayerItem:(AVPlayerItem*)playerItem;
- (void) stopObservingPlayerItem:(AVPlayerItem*)playerItem;

- (BOOL) isBeingObservedBy:(id<PRXPlayerObserver>)observer;
- (void) removeNonPersistentObservers:(BOOL)rerun;

- (void) reportPlayerStatusChangeToObservers;
- (void) reportPlayerTimeIntervalToObservers;

- (NSDictionary*) MPNowPlayingInfoCenterNowPlayingInfo;
- (void) setMPNowPlayingInfoCenterNowPlayingInfo;

@end

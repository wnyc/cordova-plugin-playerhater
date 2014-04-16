//
//  PRXPlayer.h
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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ReachabilityManager.h"

#define PRXDEBUG 1

#if PRXDEBUG
#define PRXLog(format, ...) NSLog((@"[PRX][Audio] " format), ##__VA_ARGS__)
#else
#define PRXLog(...)
#endif 

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)


@protocol PRXPlayable <NSObject>

@property (nonatomic, strong, readonly) NSURL *audioURL;
@property (nonatomic, strong, readonly) NSDictionary *mediaItemProperties;

@optional

@property (nonatomic, strong, readonly) NSDictionary *userInfo; 

- (BOOL) isEqualToPlayable:(id<PRXPlayable>)playable;

@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval playbackCursorPosition;
@property (nonatomic, readonly) BOOL isStream; 

@end

@protocol PRXPlayerObserver;

extern NSString * const PRXPlayerStatusChangeNotification;
extern NSString * const PRXPlayerTimeIntervalNotification;
extern NSString * const PRXPlayerLongTimeIntervalNotification;

@interface PRXPlayer : UIResponder <AVAudioSessionDelegate,ReachabilityManagerDelegate> {
    // used for determining when the player crosses a meaningful boundary
    id playerSoftEndBoundaryTimeObserver;
    id playerPeriodicTimeObserver;
    id playerLongPeriodicTimeObserver; 
    NSDate *lastLongPeriodicTimeObserverAction;
    
    NSUInteger backgroundKeepAliveTaskID;
    
    BOOL holdPlayback;
    BOOL waitingForPlayableToBeReadyForPlayback;
    BOOL audioSessionIsInterrupted; 
    BOOL playerIsBuffering;
    BOOL networkBecameUnreachable;
  
    NSDate* dateAtAudioPlaybackInterruption;
    
    NSUInteger retryCount;
}

+ (instancetype) sharedPlayer;
- (id) initWithAudioSessionManagement:(BOOL)manageSession;

@property (nonatomic, strong) NSObject<PRXPlayable> *currentPlayable; 
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong, readonly) AVPlayerItem *playerItem;
@property (nonatomic, readonly) BOOL isPrebuffering;
@property (nonatomic, readonly) float buffer;
@property (nonatomic, strong, readonly) NSArray *observers;

- (void) playPlayable:(id<PRXPlayable>)playable;
- (void) loadPlayable:(id<PRXPlayable>)playable;
- (void) togglePlayable:(id<PRXPlayable>)playable;

- (float) rateForPlayable:(id<PRXPlayable>)playable;
- (BOOL) isCurrentPlayable:(NSObject<PRXPlayable> *)playable;
- (BOOL) isWaitingForPlayable:(NSObject<PRXPlayable> *)playable;

- (void) play;
- (void) pause;
- (void) togglePlayPause;
- (void) stop;

- (id) addObserver:(id<PRXPlayerObserver>)observer persistent:(BOOL)persistent;
- (void) removeObserver:(id<PRXPlayerObserver>)observer;

@end

@protocol PRXPlayerObserver <NSObject>

@optional

- (void) observedPlayerStatusDidChange:(AVPlayer *)player;
- (void) observedPlayerDidObservePeriodicTimeInterval:(AVPlayer *)player;
- (void) observedPlayerDidObserveLongPeriodicTimeInterval:(AVPlayer *)player;

@end

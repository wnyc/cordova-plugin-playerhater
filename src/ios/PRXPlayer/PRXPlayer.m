
//
//  PRXPlayer.m
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

#import "PRXPlayer_private.h"
#import <MediaPlayer/MediaPlayer.h>
#import "Reachability.h"

void audioRouteChangeListenerCallback(void *inUserData, AudioSessionPropertyID inPropertyID, UInt32 inPropertyValueSize, const void *inPropertyValue) {
    PRXPlayer *player = [PRXPlayer sharedPlayer];
    [player handleAudioSessionRouteChange:inPropertyID withPropertySize:inPropertyValueSize andValue:inPropertyValue];
}

NSString * const PRXPlayerStatusChangeNotification = @"PRXPlayerStatusChangeNotification";
NSString * const PRXPlayerTimeIntervalNotification = @"PRXPlayerTimeIntervalNotification";
NSString * const PRXPlayerLongTimeIntervalNotification = @"PRXPlayerLongTimeIntervalNotification";

@implementation PRXPlayer

static const NSString* PlayerStatusContext;
static const NSString* PlayerRateContext;
static const NSString* PlayerErrorContext;
static const NSString* PlayerItemStatusContext;
static const NSString* PlayerItemBufferEmptyContext;

float LongPeriodicTimeObserver = 10.0f;

static PRXPlayer* sharedPlayerInstance;

+ (instancetype)sharedPlayer {
    @synchronized(self) {
        if (sharedPlayerInstance == nil) {
            sharedPlayerInstance = [[self alloc] init];
        }
    }
    
    return sharedPlayerInstance;
}

#pragma mark - Garbage collection

- (void)dealloc {
    [self stopObservingPlayer:self.player];
    [self stopObservingPlayerItem:self.currentPlayerItem];
}

#pragma mark - General player interface
#pragma mark Setup

- (id) init {
    self = [self initWithAudioSessionManagement:YES];
    if (self) {
        holdPlayback = YES;
    }
    return self;
}

- (id) initWithAudioSessionManagement:(BOOL)manageSession {
    self = [super init];
    if (self) {
        self.manageSession = manageSession; 
        _observers = [NSMutableArray array];
        
        [UIApplication.sharedApplication beginReceivingRemoteControlEvents];
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0")) { 
            [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(audioSessionInterruption:)
                                                   name:AVAudioSessionInterruptionNotification
                                                   object:nil];
          
            [NSNotificationCenter.defaultCenter addObserver:self
                                                   selector:@selector(audioSessionRouteChange:)
                                                       name:AVAudioSessionRouteChangeNotification
                                                     object:nil];
        }
        
        _reachManager = [[ReachabilityManager alloc] init];
        _reachManager.delegate = self; 

        [self initAudioSession];
    }
    return self;
}

- (void) initAudioSession {
    if (self.manageSession) {
        NSError *setCategoryError = nil;
        BOOL success = [[AVAudioSession sharedInstance]
                        setCategory: AVAudioSessionCategoryPlayback
                        error: &setCategoryError];
        
        if (!success) { /* handle the error in setCategoryError */ }
        NSError *activationError = nil;
        success = [[AVAudioSession sharedInstance] setActive:YES error: &activationError];
        if (!success) { /* handle the error in activationError */ }
        
        if (SYSTEM_VERSION_LESS_THAN(@"6.0")) {
            [[AVAudioSession sharedInstance] setDelegate:self];
            AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audioRouteChangeListenerCallback, (__bridge void *) self);
        }
    }
}

- (BOOL)allowsPlaybackViaWWAN {
    return YES;
}

- (NSUInteger)retryLimit {
    return 3;
}

- (void) setPlayer:(AVPlayer*)player {
    [self stopObservingPlayer:self.player];
    
    _player = player;
    
    [self observePlayer:self.player];
}

- (void) setCurrentPlayable:(NSObject<PRXPlayable> *)playable {
    if (![self isCurrentPlayable:playable]) {
            [self currentPlayableWillChange];
            
            _currentPlayable = playable;
          
          // This should not be necessary if self.player is being managed properly. Should only need to
          // set up observers on the AVPlayer when it's created. EXCEPT for the boundary timer; that needs
          // the change whenever the playable changes.
    //        [self observePlayer:self.player];
          
            waitingForPlayableToBeReadyForPlayback = YES;
            if (!holdPlayback) { playerIsBuffering = YES; }
          
            [self reportPlayerStatusChangeToObservers];
            
            self.currentURLAsset = [AVURLAsset assetWithURL:self.currentPlayable.audioURL];
    }
}

- (BOOL) isCurrentPlayable:(NSObject<PRXPlayable> *)playable {
    return [self playable:self.currentPlayable isEqualToPlayable:playable];
}

- (void) setCurrentPlayerItem:(AVPlayerItem*)currentPlayerItem {
    [self stopObservingPlayerItem:self.currentPlayerItem];
    
    _currentPlayerItem = currentPlayerItem;
    
    if (!self.player) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.player = [AVPlayer playerWithPlayerItem:self.currentPlayerItem];
            
            float version = UIDevice.currentDevice.systemVersion.floatValue;
            
            if (version >= 6.0f) {
                self.player.allowsExternalPlayback = NO;
            } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                self.player.allowsAirPlayVideo = NO;
#pragma clang diagnostic pop
            }
        });
    } else {
        [self.player replaceCurrentItemWithPlayerItem:self.currentPlayerItem];
    }
    
    [self observePlayerItem:self.currentPlayerItem];
}

- (void) setCurrentURLAsset:(AVURLAsset*)currentURLAsset {
    _currentURLAsset = currentURLAsset;
  
    [self.player removeTimeObserver:playerSoftEndBoundaryTimeObserver];
    playerSoftEndBoundaryTimeObserver = nil;
    
    [self.currentURLAsset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error;
            AVKeyValueStatus status = [self.currentURLAsset statusOfValueForKey:@"tracks" error:&error];
            
            if (status == AVKeyValueStatusLoaded) {
                [self didLoadTracksForAsset:self.currentURLAsset];
            } else {
                [self failedToLoadTracksForAsset:self.currentURLAsset];
            }
        });
    }];
}

#pragma mark Exposure

- (AVPlayerItem*) playerItem {
    return self.currentPlayerItem;
}

- (float) buffer {
    CMTimeRange tr;
    [[self.player.currentItem.loadedTimeRanges lastObject] getValue:&tr];
    
    CMTime duration = tr.duration;
    return MAX(0.0f, CMTimeGetSeconds(duration));
}

- (float) rateForPlayable:(NSObject<PRXPlayable> *)playable {
    if ([self isCurrentPlayable:playable]) {
        return self.player.rate;
    }
    return 0.0f;
}

- (BOOL) isWaitingForPlayable:(NSObject<PRXPlayable> *)playable {
  return ([self isCurrentPlayable:playable] && waitingForPlayableToBeReadyForPlayback);
}

- (BOOL) playable:(id<PRXPlayable>)playable isEqualToPlayable:(id<PRXPlayable>)otherPlayable {
    if ([playable respondsToSelector:@selector(isEqualToPlayable:)]
        && [otherPlayable respondsToSelector:@selector(isEqualToPlayable:)]) {
        return [playable isEqualToPlayable:otherPlayable];
    } else {
        return [playable.audioURL isEqual:otherPlayable.audioURL];
    }
}

#pragma mark Asynchronous loading callbacks

- (void) didLoadTracksForAsset:(AVURLAsset*)asset {
    self.currentPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
}

- (void) failedToLoadTracksForAsset:(AVURLAsset*)asset {
    // loading the tracks using a player url asset is more reliable and has already been tried
    // by the time we get here.  but if it fails we can still try to set the player item directly. 
    self.currentPlayerItem = [AVPlayerItem playerItemWithURL:self.currentPlayable.audioURL];
}

#pragma mark Controls

- (void) loadPlayable:(NSObject<PRXPlayable> *)playable {
    holdPlayback = YES;
    retryCount = 0;
    [self preparePlayable:playable];
}

- (void) playPlayable:(NSObject<PRXPlayable> *)playable {
    holdPlayback = NO;
    retryCount = 0;
    [self preparePlayable:playable];
}

- (void) togglePlayable:(id<PRXPlayable>)playable {
  if ([self rateForPlayable:playable] == 0.0f) {
    [self playPlayable:playable];
  } else {
    [self pause];
  }
}

- (void) preparePlayable:(NSObject<PRXPlayable> *)playable {
    dateAtAudioPlaybackInterruption = nil;
    
    if (![self isCurrentPlayable:playable]) {
        waitingForPlayableToBeReadyForPlayback = NO;
    }
    
    [self loadAndPlayPlayable:playable];
}

- (void) loadAndPlayPlayable:(id<PRXPlayable>)playable {
    if ([self isCurrentPlayable:playable]) {
        [self handleCurrentPlayable];
    } else {
        [self handleNewPlayable:playable];
    }
}

- (void) handleCurrentPlayable {
    if (![self.currentURLAsset.URL isEqual:self.currentPlayable.audioURL]) {
        PRXLog(@"Switching to stream or local file because other is no longer available %@", self.currentPlayable.audioURL);
        
        waitingForPlayableToBeReadyForPlayback = YES;
        if (!holdPlayback) { playerIsBuffering = YES; }
        
        self.currentURLAsset = [AVURLAsset assetWithURL:self.currentPlayable.audioURL];
    } else if ([self rateForPlayable:self.currentPlayable] > 0.0f) {
        PRXLog(@"Playable is already playing");
        
        waitingForPlayableToBeReadyForPlayback = NO;
        return;
    } else if ([self rateForPlayable:self.currentPlayable] == 0.0f && !waitingForPlayableToBeReadyForPlayback
                && !audioSessionIsInterrupted) {
        PRXLog(@"Resume (or start) playing current playable");
        
        if (dateAtAudioPlaybackInterruption) {
            NSTimeInterval intervalSinceInterrupt = [NSDate.date timeIntervalSinceDate:dateAtAudioPlaybackInterruption];
            PRXLog(@"Appear to be recovering from an interrupt that's %fs old", intervalSinceInterrupt);
            BOOL withinResumeTimeLimit = (self.interruptResumeTimeLimit < 0) || (intervalSinceInterrupt <= self.interruptResumeTimeLimit);

            if (!withinResumeTimeLimit) {
                PRXLog(@"Internal playback request after an interrupt, but waited too long; exiting.");
                dateAtAudioPlaybackInterruption = nil; 
                return;
            }
        }
        
        self.reachManager.reach.reachableOnWWAN = self.allowsPlaybackViaWWAN;
        if (self.reachManager.reach.isReachable || [self.currentPlayable.audioURL isFileURL]) {
            dateAtAudioPlaybackInterruption = nil; 
            if ([self.currentPlayable respondsToSelector:@selector(playbackCursorPosition)]) {
                float startTimeSeconds = ((CMTimeGetSeconds(self.player.currentItem.duration) - self.currentPlayable.playbackCursorPosition < 3.0f) ? 0.0f : self.currentPlayable.playbackCursorPosition);
                CMTime startTime = CMTimeMakeWithSeconds(startTimeSeconds, 1);
                
                [self.player seekToTime:startTime completionHandler:^(BOOL finished){
                    if (finished && !holdPlayback) {
                        self.player.rate = self.rateForPlayback;
                    } else {
                        PRXLog(@"Not starting playback because of hold or seek interruption");
                    }
                }];
            } else if (!holdPlayback) {
                self.player.rate = self.rateForPlayback;
            } else {
                PRXLog(@"Not starting playback because of a hold");
            }
        } else {
            PRXLog(@"Aborting playback, network not reachable");
        }
    } else {
        // should never get here.
        // generally, assuming the waiting flag is correct, we just want to keep waiting...
    }
}

- (void) handleNewPlayable:(id<PRXPlayable>)playable {
    self.reachManager.reach.reachableOnWWAN = self.allowsPlaybackViaWWAN;
    
    if (self.reachManager.reach.isReachable || [playable.audioURL isFileURL]) {
        PRXLog(@"Loading episode into player, playback will start async");
        self.currentPlayable = playable;
    } else {
        PRXLog(@"Aborting loading, network not reachable");
    }
}

- (void) reloadAndPlayPlayable:(NSObject<PRXPlayable> *)playable {
    PRXLog(@"reloadAndPlayPlayable %@", [NSDate date]); 
    BOOL hold = holdPlayback;
    [self stop];
    holdPlayback = hold;
    [self preparePlayable:playable];
}

- (void) play {
    if (self.currentPlayable) {
        holdPlayback = NO; 
        [self loadAndPlayPlayable:self.currentPlayable];
    }
}

- (void) pause {
    self.player.rate = 0.0f;
    playerIsBuffering = NO;
  
    // Hold is being set to prevent cases where the player item unexpectedly reports as being ReadyForPlayback
    // which could cause it to start playing. In iOS 6.0+ this can occur when audio interrupts end.
    // This may be unnecessary when, in playerItemStatusDidChange, playback is only being started if the status
    // actually changed, not any time the player item is reported as ready.
    holdPlayback = YES;
}

- (void) togglePlayPause {
    if (self.player.rate > 0.0f) {
        [self pause];
    } else {
        [self play];
    }
}

- (void) stop {
    PRXLog(@"Stop has been called on the audio player; resetting everything;");
  
    playerIsBuffering = NO;
    waitingForPlayableToBeReadyForPlayback = NO;
    holdPlayback = YES;
  
    _currentPlayable = nil;
  
    _currentPlayerItem = nil;
    _currentURLAsset = nil;
    [self.player removeTimeObserver:playerSoftEndBoundaryTimeObserver];
    playerSoftEndBoundaryTimeObserver = nil; 
    _player.rate = 0.0;
    _player = nil;
  
    [self reportPlayerStatusChangeToObservers];
}

#pragma mark Target playback rates

- (float) rateForFilePlayback {
    return 1.0f;
}

- (float) rateForPlayback {
    return (self.currentPlayerItem.duration.value > 0 ? self.rateForFilePlayback : 1.0f);
}

#pragma mark Soft end

- (float) softEndBoundaryProgress {
    return 0.95f;
}

#pragma mark Callbacks

- (void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if (context == &PlayerStatusContext) {
        [self playerStatusDidChange:change];
        return;
    } else if (context == &PlayerRateContext) {
        [self playerRateDidChange:change];
        return;
    } else if (context == &PlayerErrorContext) {
        [self playerErrorDidChange:change];
        return;
    } else if (context == &PlayerItemStatusContext) {
        [self playerItemStatusDidChange:change];
        return;
    } else if (context == &PlayerItemBufferEmptyContext) {
//        [self playerItemStatusDidChange:change];
        [self playerItemBufferEmptied:change];
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    return;
}

- (void) currentPlayableWillChange {
    if (self.currentPlayable) {
        // [self pause];
        self.player.rate = 0.0f;
        [self removeNonPersistentObservers:YES];
        [self.player removeTimeObserver:playerSoftEndBoundaryTimeObserver];
        playerSoftEndBoundaryTimeObserver = nil;
      
      // This should not be necessary if self.player is being managed properly. Should only need to
      // kill observers on the AVPlayer when the player itself is killed (in stop).
      // EXCEPT for the boundary timer; that needs
      // to change whenever the playable changes.
//        [self stopObservingPlayer:self.player];
    }
}

- (void) playerStatusDidChange:(NSDictionary*)change {
    [self reportPlayerStatusChangeToObservers];
}

- (void) playerRateDidChange:(NSDictionary*)change {    
    [self reportPlayerStatusChangeToObservers];
}

- (void) playerErrorDidChange:(NSDictionary*)change {
    [self stop];
    [self reportPlayerStatusChangeToObservers];
}

- (void) playerItemStatusDidChange:(NSDictionary*)change {
    [self reportPlayerStatusChangeToObservers];
    
    NSUInteger keyValueChangeKind = [change[NSKeyValueChangeKindKey] integerValue];
  
    if (keyValueChangeKind == NSKeyValueChangeSetting) {
        id _new = change[NSKeyValueChangeNewKey];
        id _old = change[NSKeyValueChangeOldKey];
        PRXLog(@"AVPlayerItem status changed from %@ to %@", _old, _new);

        if (self.player.currentItem.status == AVPlayerStatusReadyToPlay) {
            waitingForPlayableToBeReadyForPlayback = NO;
            playerIsBuffering = NO; 
            retryCount = 0;
            
            [self setMPNowPlayingInfoCenterNowPlayingInfo];
            PRXLog(@"Player item has become ready to play; pass it back to playEpisode: to get it to start playback.");
          
            // Find a better place for this
            if (self.player.currentItem.duration.value > 0) {
                int64_t boundryTime = ((double)self.player.currentItem.duration.value * self.softEndBoundaryProgress);
                CMTime boundry = CMTimeMake(boundryTime, self.player.currentItem.duration.timescale);
                
                NSValue* _boundry = [NSValue valueWithCMTime:boundry];
                
                __weak id this = self;
                
                playerSoftEndBoundaryTimeObserver = [self.player addBoundaryTimeObserverForTimes:@[ _boundry ] queue:dispatch_queue_create("playerQueue", NULL) usingBlock:^{
                  [this playerSoftEndBoundaryTimeObserverAction];
                }];
            }
        
            [self loadAndPlayPlayable:self.currentPlayable];
        } else if (self.player.currentItem.status == AVPlayerStatusFailed) {
            PRXLog(@"Player status failed %@", self.player.currentItem.error);
            // the AVPlayer has trouble switching from stream to file and vice versa
            // if we get an error condition, start over playing the thing it tried to play.
            // Once a player fails it can't be used for playback anymore!
            waitingForPlayableToBeReadyForPlayback = NO;
            
            if (retryCount < self.retryLimit) {
                retryCount++;
              
                PRXLog(@"Retrying (retry number %i of %i)", retryCount, self.retryLimit);
              
                NSObject<PRXPlayable> *playableToRetry = self.currentPlayable;
                [self stop];
                
                [self preparePlayable:playableToRetry];
            } else {
                PRXLog(@"Playable failed to become ready even after retries.");
                [self stop];
                _currentPlayable = nil;
                [self reportPlayerStatusChangeToObservers];
            }
            
        } else {
            // AVPlayerStatusUnknown
            PRXLog(@"+++++++++++++++++ AVPlayerStatusUnknown +++++++++++++");
            PRXLog(@"This shouldn't happen after an item has become ready.");
        }
    }
}

- (void) playerItemBufferEmptied:(NSDictionary*)change {
    PRXLog(@"Buffer emptied...");
    
    if (self.currentPlayable) {
        if ([self.currentPlayable.audioURL isFileURL]) {
            PRXLog(@"...but was a local file; no need to restart.");
        } else if (!self.reachManager.reach.isReachable) {
            PRXLog(@"...and we don't have connectivity for a remote file/stream; flag for a restart when we do...");
            dateAtAudioPlaybackInterruption = [NSDate date];
        } else {
            PRXLog(@"...and was a remote file, but we still have connectivity...");
            [self reloadAndPlayPlayable:self.currentPlayable];
        }
    }
  
    [self reportPlayerStatusChangeToObservers];
}

- (void) playerPeriodicTimeObserverAction {
//    NSLog(@">>>>>>>> BUFFER %f", self.buffer);
    [self reportPlayerTimeIntervalToObservers];
}

- (void) playerLongPeriodicTimeObserverAction {
    NSTimeInterval since = [lastLongPeriodicTimeObserverAction timeIntervalSinceNow];
    
    if (ABS(since) > LongPeriodicTimeObserver || !lastLongPeriodicTimeObserverAction) {
        lastLongPeriodicTimeObserverAction = [NSDate date];
        [self reportPlayerLongTimeIntervalToObservers]; 
    }
}

- (void) playerSoftEndBoundaryTimeObserverAction {
}

- (void) playerItemDidPlayToEndTime:(NSNotification*)notification {
    [self reportPlayerStatusChangeToObservers];
}

- (void) playerItemDidJumpTime:(NSNotification*)notification {
    [self reportPlayerTimeIntervalToObservers];
}

#pragma mark Internal observers

- (void) observePlayer:(AVPlayer*)player {
    [player addObserver:self forKeyPath:@"status" options:0 context:&PlayerStatusContext];
    [player addObserver:self forKeyPath:@"rate" options:0 context:&PlayerRateContext];
    [player addObserver:self forKeyPath:@"error" options:0 context:&PlayerRateContext];
    
    playerPeriodicTimeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_queue_create("playerQueue", NULL) usingBlock:^(CMTime time) {
        [self playerPeriodicTimeObserverAction];
    }];
    
    playerLongPeriodicTimeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(10, 1) queue:dispatch_queue_create("playerQueue", NULL) usingBlock:^(CMTime time) {
        [self playerLongPeriodicTimeObserverAction];
    }];
}

- (void) stopObservingPlayer:(AVPlayer*)player {
    [player removeObserver:self forKeyPath:@"status"];
    [player removeObserver:self forKeyPath:@"rate"];
    [player removeObserver:self forKeyPath:@"error"];
    
    [player removeTimeObserver:playerPeriodicTimeObserver];
    [player removeTimeObserver:playerLongPeriodicTimeObserver];
    [player removeTimeObserver:playerSoftEndBoundaryTimeObserver];
    playerPeriodicTimeObserver = nil;
    playerLongPeriodicTimeObserver = nil;
    playerSoftEndBoundaryTimeObserver = nil;
}

- (void) observePlayerItem:(AVPlayerItem*)playerItem {
    [playerItem addObserver:self forKeyPath:@"status" options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:&PlayerItemStatusContext];
    [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:&PlayerItemBufferEmptyContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:playerItem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidJumpTime:)
                                                 name:AVPlayerItemTimeJumpedNotification
                                               object:playerItem];
}

- (void) stopObservingPlayerItem:(AVPlayerItem*)playerItem {
    [playerItem removeObserver:self forKeyPath:@"status"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:playerItem];
}

#pragma mark External observers

- (id) addObserver:(id<PRXPlayerObserver>)observer persistent:(BOOL)persistent {
    if (![self isBeingObservedBy:observer]) {
        NSNumber* _persistent = @(persistent);
        NSDictionary* dict = @{ @"obj":observer, @"persist":_persistent };
        
        NSMutableArray* mArr = [NSMutableArray arrayWithArray:_observers];
        [mArr addObject:dict];
        _observers = [NSArray arrayWithArray:mArr];
    }
    
    return @"YES";
}

- (void) removeObserver:(id<PRXPlayerObserver>)observer {
    NSMutableArray* discardItems = [NSMutableArray array];
    
    for (NSDictionary* dict in _observers) {
        if ([dict[@"obj"] isEqual:observer]) {
            [discardItems addObject:dict];
        }
    }
    
    NSMutableArray* mArr = [NSMutableArray arrayWithArray:_observers];
    [mArr removeObjectsInArray:discardItems];
    _observers = [NSArray arrayWithArray:mArr];
}

- (BOOL) isBeingObservedBy:(id<PRXPlayerObserver>)observer {
    for (NSDictionary* dict in _observers) {
        if ([dict[@"obj"] isEqual:observer]) {
            return YES;
        }
    }
    return NO;
}

- (void) removeNonPersistentObservers:(BOOL)rerun {
    NSMutableArray* discardItems = [NSMutableArray array];
    
    for (NSDictionary* dict in _observers) {
        if ([dict[@"persist"] isEqualToNumber:@NO]) {
            [discardItems addObject:dict];
            id<PRXPlayerObserver> observer = dict[@"obj"];
            
            if (rerun) {
                [observer observedPlayerStatusDidChange:self.player];
                [observer observedPlayerDidObservePeriodicTimeInterval:self.player];
            }
        }
    }
    
    NSMutableArray* mArr = [NSMutableArray arrayWithArray:_observers];
    [mArr removeObjectsInArray:discardItems];
    _observers = [NSArray arrayWithArray:mArr];
}

- (void) reportPlayerStatusChangeToObservers {
  [NSNotificationCenter.defaultCenter postNotificationName:PRXPlayerStatusChangeNotification
                                                    object:self.currentPlayable
                                                  userInfo:nil];

  
    for (NSDictionary* dict in _observers) {
        id<PRXPlayerObserver> observer = dict[@"obj"];
        if ([observer respondsToSelector:@selector(observedPlayerStatusDidChange:)]) {
            [observer observedPlayerStatusDidChange:self.player];
        }
    }
}

- (void) reportPlayerTimeIntervalToObservers {
  [NSNotificationCenter.defaultCenter postNotificationName:PRXPlayerTimeIntervalNotification
                                                    object:self.currentPlayable
                                                  userInfo:nil];

    for (NSDictionary* dict in _observers) {
        id<PRXPlayerObserver> observer = dict[@"obj"];
        if ([observer respondsToSelector:@selector(observedPlayerDidObservePeriodicTimeInterval:)]) {
            [observer observedPlayerDidObservePeriodicTimeInterval:self.player];
        }
    }
}

- (void) reportPlayerLongTimeIntervalToObservers {
  [NSNotificationCenter.defaultCenter postNotificationName:PRXPlayerLongTimeIntervalNotification
                                                    object:self.currentPlayable
                                                  userInfo:nil];

    for (NSDictionary* dict in _observers) {
        id<PRXPlayerObserver> observer = dict[@"obj"];
        if ([observer respondsToSelector:@selector(observedPlayerDidObserveLongPeriodicTimeInterval:)]) {
            [observer observedPlayerDidObserveLongPeriodicTimeInterval:self.player];
        }
    }
}

#pragma mark Keep Alive

- (void) keepAliveInBackground {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self beginBackgroundKeepAlive];
        for (int i = 0; i < 24; i++)  {
            NSLog(@"keeping alive %d", i * 10);
            [NSThread sleepForTimeInterval:10];
        }
        [self endBackgroundKeepAlive];
    });
}

- (void) beginBackgroundKeepAlive {
    backgroundKeepAliveTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundKeepAlive];
    }];
}

- (void) endBackgroundKeepAlive {
    [[UIApplication sharedApplication] endBackgroundTask:backgroundKeepAliveTaskID];
    backgroundKeepAliveTaskID = UIBackgroundTaskInvalid;
}

#pragma mark Reachability Interruption

- (void) reachabilityDidChangeFrom:(NetworkStatus)oldReachability to:(NetworkStatus)newReachability {
    PRXLog(@"Reachability did change from %d to %d %@", oldReachability, newReachability, [NSDate date]);
    if (newReachability == NotReachable) {
        [self keepAliveInBackground];
    } else if (newReachability == ReachableViaWiFi) {
        if (oldReachability == NotReachable) {      // if we just got a connection back, we may want to restart playing
            [self stopPlayerAndRetry];
        } else if (oldReachability == ReachableViaWWAN) {  // we want to shift to wifi so we don't keep using 3G
            [self stopPlayerAndRetry]; 
        }
    } else if (newReachability == ReachableViaWWAN) {
        if (oldReachability == NotReachable) {
            [self stopPlayerAndRetry];
        }
    }
}

- (void) stopPlayerAndRetry {
    PRXLog(@"stopPlayerAndRetry %@", [NSDate date]); 
    if (self.currentPlayable && ![self.currentPlayable.audioURL isFileURL]) {
        [self reloadAndPlayPlayable:self.currentPlayable];
    }
}

#pragma mark Audio Session Interruption

- (void) audioSessionInterruption:(NSNotification*)notification {
    PRXLog(@"An audioSessionInterruption notification was received");
    id interruptionTypeKey = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    
    if ([interruptionTypeKey isEqual:@(AVAudioSessionInterruptionTypeBegan)]) {
        [self audioSessionDidBeginInterruption:notification];
    } else if ([interruptionTypeKey isEqual:@(AVAudioSessionInterruptionTypeEnded)]) {
        [self audioSessionDidEndInterruption:notification];
    }
}

- (void) audioSessionDidBeginInterruption:(NSNotification*)notification {
    PRXLog(@"Audio session has been interrupted %f...", self.player.rate);
    audioSessionIsInterrupted = YES; 
    [self keepAliveInBackground];
    dateAtAudioPlaybackInterruption = NSDate.date;
}

- (void) audioSessionDidEndInterruption:(NSNotification*)notification {
    PRXLog(@"Audio session has interruption ended...");
    audioSessionIsInterrupted = NO; 
    
    // Because of various bugs and unpredictable behavior, it is unreliable to
    // try and recover from audio session interrupts.
    //
    // When something is loaded into AVPlayer and the interrupt ends, even without
    // us doing anything, the player item's status will change. We need to make
    // sure our handling of that change is appropriate
    //
    // If AVPlayer changes to consistently report player rate at the time of the
    // interrupt, or it is able to report interrupts when the rate is 0, this
    // could be handled more directly.
    //
    // As it is now, is the player is paused going into the interrupt, we kmow
    // the hold flag is set, so when the status changes, even though it will
    // go through the play handler, it won't start playback.
    // In cases where the audio was playing at the interrupt, the hold flag
    // simply won't be set, so it will resume in the play handler.

    [self initAudioSession];
    
    // Apparently sometimes the status change does not get reported as soon as
    // the intr. ends, so we do need to coerce it in some cases.
    // REAL DUMB.

    if (dateAtAudioPlaybackInterruption && self.currentPlayable) {
        [self loadAndPlayPlayable:self.currentPlayable];
    }
    
}

- (NSTimeInterval) interruptResumeTimeLimit {
    return (60 * 4);
}

#pragma mark Route changes

- (void) handleAudioSessionRouteChange:(AudioSessionPropertyID)inPropertyID withPropertySize:(UInt32)inPropertyValueSize andValue:(const void *)inPropertyValue {
    if (SYSTEM_VERSION_LESS_THAN(@"6.0")) {
        if (inPropertyID != kAudioSessionProperty_AudioRouteChange) { return; }
        
        CFDictionaryRef routeChangeDictionary = inPropertyValue;
        CFNumberRef routeChangeReasonRef = CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
        SInt32 routeChangeReason;
        CFNumberGetValue (routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
        
        PRXLog(@"Audio session route changed: %i", (int)routeChangeReason);
        
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
            // Headset is unplugged..
            [self pause];
        } else if (routeChangeReason == kAudioSessionRouteChangeReason_NewDeviceAvailable) {
            // Headset is plugged in..
        } else {
            //    NSLog(@"\n\n\routeChangeReason: %d\n\n\n", routeChangeReason);
        }
    }
}

- (void) audioSessionRouteChange:(NSNotification*)notification {
    NSUInteger reason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
    
    PRXLog(@"Audio session route changed: %i", reason);
    //  AVAudioSessionRouteDescription* previousRoute = notification.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    //  AVAudioSessionRouteDescription* currentRoute = [AVAudioSession.sharedInstance currentRoute];
    
    switch (reason) {
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            [self pause];
            break;
        default:
            break;
    }
}

#pragma mark - Remote control

- (BOOL) canBecomeFirstResponder {
    return YES;
}

- (BOOL) becomeFirstResponder {
	[super becomeFirstResponder];
	return YES;
}

- (NSDictionary*) MPNowPlayingInfoCenterNowPlayingInfo {
    NSMutableDictionary *info;
    
    if (self.currentPlayable && self.currentPlayable.mediaItemProperties) {
        info = self.currentPlayable.mediaItemProperties.mutableCopy;
    } else {
        info = [NSMutableDictionary dictionaryWithCapacity:10];
    }
    
    //    Set defaults if missing
    NSArray* metadata = self.player.currentItem.asset.commonMetadata;
    
    if (!info[MPMediaItemPropertyPlaybackDuration]) {
        float _playbackDuration = self.currentPlayerItem ? CMTimeGetSeconds(self.currentPlayerItem.duration) : 0.0f;
        NSNumber* playbackDuration = @(_playbackDuration);
        info[MPMediaItemPropertyPlaybackDuration] = playbackDuration;
    }
    
    if (!info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) {
        float _elapsedPlaybackTime = self.currentPlayerItem ? CMTimeGetSeconds(self.currentPlayerItem.currentTime) : 0.0f;
        NSNumber* elapsedPlaybackTime = @(_elapsedPlaybackTime);
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedPlaybackTime;
    }
    
    if (!info[MPMediaItemPropertyArtwork]) {
        NSArray* artworkMetadata = [AVMetadataItem metadataItemsFromArray:metadata
                                                                  withKey:AVMetadataCommonKeyArtwork
                                                                 keySpace:AVMetadataKeySpaceCommon];
        if (artworkMetadata.count > 0) {
            AVMetadataItem* artworkMetadataItem = artworkMetadata[0];
            
            UIImage* artworkImage = [UIImage imageWithData:artworkMetadataItem.value[@"data"]];
            MPMediaItemArtwork* artwork = [[MPMediaItemArtwork alloc] initWithImage:artworkImage];
            
            info[MPMediaItemPropertyArtwork] = artwork;
        }
    }
    
    if (!info[MPMediaItemPropertyTitle]) {
        NSArray* _metadata = [AVMetadataItem metadataItemsFromArray:metadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
        
        if (_metadata.count > 0) {
            AVMetadataItem* _metadataItem = _metadata[0];
            info[MPMediaItemPropertyTitle] = _metadataItem.value;
        }
    }

    if (!info[MPMediaItemPropertyAlbumTitle]) {
        NSArray* _metadata = [AVMetadataItem metadataItemsFromArray:metadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
        
        if (_metadata.count > 0) {
            AVMetadataItem* _metadataItem = _metadata[0];
            info[MPMediaItemPropertyAlbumTitle] = _metadataItem.value;
        }
    }
    
    if (!info[MPMediaItemPropertyArtist]) {
        NSArray* _metadata = [AVMetadataItem metadataItemsFromArray:metadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
        
        if (_metadata.count > 0) {
            AVMetadataItem* _metadataItem = _metadata[0];
            info[MPMediaItemPropertyArtist] = _metadataItem.value;
        }
    }
    
    return info; 
}

- (void) setMPNowPlayingInfoCenterNowPlayingInfo {
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = self.MPNowPlayingInfoCenterNowPlayingInfo;
}

- (void) remoteControlReceivedWithEvent:(UIEvent*)event {
	switch (event.subtype) {
		case UIEventSubtypeNone:
			break;
		case UIEventSubtypeMotionShake:
			break;
		case UIEventSubtypeRemoteControlPlay:
            [self play];
			break;
		case UIEventSubtypeRemoteControlPause:
            [self pause];
			break;
		case UIEventSubtypeRemoteControlStop:
            [self stop];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
            [self togglePlayPause];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
			break;
		case UIEventSubtypeRemoteControlPreviousTrack:
			break;
		case UIEventSubtypeRemoteControlBeginSeekingBackward:
			break;
		case UIEventSubtypeRemoteControlEndSeekingBackward:
			break;
		case UIEventSubtypeRemoteControlBeginSeekingForward:
			break;
		case UIEventSubtypeRemoteControlEndSeekingForward:
			break;
		default:
			break;
	}
}

#pragma mark - AVAudioSession Delegate Methods

- (void)beginInterruption {
    PRXLog(@"AVAudioSession Delegate beginInterruption");
    [self audioSessionDidBeginInterruption:nil];
}

- (void)endInterruption {
    PRXLog(@"AVAudioSession Delegate endInterruption");
//    [[AVAudioSession sharedInstance] setActive:YES];
//    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [self audioSessionDidEndInterruption:nil];
}

- (void)endInterruptionWithFlags:(NSUInteger)flags {
    PRXLog(@"AVAudioSession Delegate endInterruptionWithFlags");
    [self endInterruption];
}

- (void)inputIsAvailableChanged:(BOOL)isInputAvailable {
    
}

@end

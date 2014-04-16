#import "NYPRPlayer.h"
#import "PRXPlayer_private.h"

@implementation NYPRPlayer
@synthesize mNetworkStatus;

- (NYPRPlayer*) initWithCDVReachability:(CDVReachability*)reachability
{
    self = [super init];
    
    mNetworkStatus = reachability;
    Reachability * reach = [[Reachability alloc] initWithCDVReachability:mNetworkStatus];
    [self.reachManager setReach:reach];
    
    return self;
}

- (void) setObserver:(id<NYPRPlayerObserver>)observer{
    mNYPRPlayerObserver=observer;
}

- (BOOL) isPlayingAtPositiveRate {
    return self.player.rate > 0.0f;
}

- (BOOL) isBuffering {
    return playerIsBuffering;
}

- (BOOL) isPaused {
    return self.player.rate == 0.0f && playerIsBuffering == NO && holdPlayback == YES;
}

- (void) skipBack:(NSTimeInterval)interval {
    
    if( self.player.currentItem.duration.value > 0 ) {
        CMTime skipTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(self.player.currentTime) - interval, 10);
        [self.player seekToTime:skipTime];
    }else{
        NSLog(@"seek not available");
    }
}

- (void) skipForward:(NSTimeInterval)interval {
    if( self.player.currentItem.duration.value > 0 ) {
        CMTime skipTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(self.player.currentTime) + interval, 10);
        [self.player seekToTime:skipTime];
    }else{
        NSLog(@"seek not available");
    }
}

- (void) skipTo:(NSTimeInterval)interval {
    if( self.player.currentItem.duration.value > 0 ) {
        CMTime skipTime = CMTimeMakeWithSeconds(interval, 10);
        [self.player seekToTime:skipTime];
    }else{
        NSLog(@"seek not available");
    }
}



#pragma mark -- Overrides

- (void) playerItemDidPlayToEndTime:(NSNotification*)notification {
    
    NSLog(@"Item Played Until End Time!");
    
    if(self->mNYPRPlayerObserver){
        [self->mNYPRPlayerObserver observedNYPRPlayerDidCompleteFile];
    }
    
    [self reportPlayerStatusChangeToObservers];
}

- (void) playerRateDidChange:(NSDictionary*)change {

    if([self isPlayingAtPositiveRate]){
        if(self->mNYPRPlayerObserver){
            // not sure if the rate could go from one positive rate to another positive rate,
            // which could trigger additional 'starts', though that might not matter
            [self->mNYPRPlayerObserver observedNYPRPlayerDidStart];
        }
    } else {

        if( ! [self currentPlayable] ){
            if(self->mNYPRPlayerObserver){
                [self->mNYPRPlayerObserver observedNYPRPlayerDidStop];
            }
        }
    }
    
    [self reportPlayerStatusChangeToObservers];
}

- (void) pause {
    [super pause];
    if ([self.currentPlayable respondsToSelector:@selector(playbackCursorPosition)]) {
        self.currentPlayable.playbackCursorPosition = CMTimeGetSeconds(self.player.currentItem.currentTime);
    }
    if(self->mNYPRPlayerObserver){
        // not sure if the rate could go from one positive rate to another positive rate,
        // which could trigger additional 'starts', though that might not matter
        [self->mNYPRPlayerObserver observedNYPRPlayerDidPause];
    }
}

- (NSTimeInterval) availableDuration
{
    NSTimeInterval result = 0;
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    if ( [loadedTimeRanges count] > 0) {
        CMTimeRange timeRange = [[loadedTimeRanges objectAtIndex:0] CMTimeRangeValue];
        float startSeconds = CMTimeGetSeconds(timeRange.start);
        float durationSeconds = CMTimeGetSeconds(timeRange.duration);
        result = startSeconds + durationSeconds;
    }else {
        NSLog(@"no available duration");
    }
    return result;
}

- (NSDictionary*) MPNowPlayingInfoCenterNowPlayingInfo {
    NSDictionary * info = [super MPNowPlayingInfoCenterNowPlayingInfo];
    NSMutableDictionary *newInfo = [info mutableCopy];
    
    if( mLockScreenTitle!=nil ) {
        newInfo[MPMediaItemPropertyTitle] = mLockScreenTitle;
    }
    
    if( mLockScreenDescription!=nil ){
        newInfo[MPMediaItemPropertyAlbumTitle] = mLockScreenDescription;
    }
        
    if ( mLockScreenArt != nil ) {
        newInfo[MPMediaItemPropertyArtwork] = mLockScreenArt;
    }
    
    if ([self.currentPlayable isStream]){
        mLockScreenDuration=nil;
        mLockScreenDuration=[[NSNumber alloc]initWithDouble:CMTimeGetSeconds(self.player.currentItem.currentTime)];
        newInfo[MPMediaItemPropertyPlaybackDuration] = mLockScreenDuration;
    }
    
    return newInfo;
}

- (void)setAudioInfo:(NSString*)title artist:(NSString*)artist artwork:(NSString*)artwork{
    
    if (mLockScreenTitle!=nil){
        mLockScreenTitle=nil;
    }
    
    if (mLockScreenDescription!=nil){
        mLockScreenDescription=nil;
    }
    
    if (title){
        mLockScreenTitle=[[NSString alloc]initWithString:title];
    }
    
    if (artist) {
        mLockScreenDescription=[[NSString alloc]initWithString:artist];
    }
    
    [self setMPNowPlayingInfoCenterNowPlayingInfo];
    
    // reload artwork if it has changed
    if (artwork) {
        if ( mLockScreenUrl != nil && mLockScreenArt!=nil && [artwork isEqualToString:mLockScreenUrl] ) {
            // image is the same -- do nothing
        } else {
            // image changed... load in background
            [self performSelectorInBackground:@selector(loadLockscreenImage:) withObject:artwork];
        }
    }
}

- (void)loadLockscreenImage:(NSString*)artwork
{
    if (mLockScreenUrl!=nil){
        mLockScreenUrl=nil;
    }
    if (mLockScreenArt!=nil){
        mLockScreenArt=nil;
    }
    mLockScreenUrl=[[NSString alloc]initWithString:artwork];
    
    // load the artwork into mLockScreenArt -- right now direct from network
    NSLog(@"Retrieving lock screen art...");
    NSURL *url = [NSURL URLWithString:mLockScreenUrl];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSLog(@"Initializing lock screen art...");
    UIImage *img = [[UIImage alloc] initWithData:data];
    if (img){
        NSLog(@"Creating MPMediaItemArtwork...");
        mLockScreenArt = [[MPMediaItemArtwork alloc] initWithImage: img];
    }
    
    [self setMPNowPlayingInfoCenterNowPlayingInfo];
    
    NSLog(@"Done retrieving lock screen art.");
}

// overrode this function simply to change CMTime startTime = CMTimeMakeWithSeconds(startTimeSeconds, 1) to CMTime startTime = CMTimeMakeWithSeconds(startTimeSeconds, 1000);
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
                CMTime startTime = CMTimeMakeWithSeconds(startTimeSeconds, 1000);
                
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

- (void) refreshMetadata {
    [self setMPNowPlayingInfoCenterNowPlayingInfo];
}

- (void) audioSessionDidBeginInterruption:(NSNotification*)notification {
    [super audioSessionDidBeginInterruption:notification];
    [self->mNYPRPlayerObserver observedNYPRPlayerDidPause];
}

@end

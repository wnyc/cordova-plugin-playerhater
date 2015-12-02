//
//  AudioStreamHandler.m
//  NYPRNativeFeatures
//
//  Created by Brad Kammin on 11/16/12.
//
//

#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>
#import <AVFoundation/AVFoundation.h>
#import "CDVSound.h"
#import "AudioStreamHandler.h"

#import "NYPRPlayer.h"
#import "NYPRStream.h"
#import "NYPROnDemand.h"

enum NYPRExtraMediaStates {
    MEDIA_LOADING = MEDIA_STOPPED + 1,
    MEDIA_COMPLETED = MEDIA_STOPPED + 2,
    MEDIA_PAUSING = MEDIA_STOPPED + 3,
    MEDIA_STOPPING = MEDIA_STOPPED + 4
};
typedef NSUInteger NYPRExtraMediaStates;

@implementation AudioStreamHandler
@synthesize mPRXBasePlayer;
@synthesize mNetworkStatus;


- (id) init
{
    self = [super init];
    mFile=nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRemoteControlEvent:) name:@"RemoteControlEventNotification" object:nil];
    return self;
}

- (AudioStreamHandler*) initWithCDVReachability:(CDVReachability*)reachability{
    self = [self init];
    mNetworkStatus = reachability;
    return self;
}

- (BOOL)startPlayingStream:(NSString*)streamFile{
    BOOL ret=TRUE;
    if([mNetworkStatus currentReachabilityStatus] != NotReachable){
        [self startPlayingInternal:streamFile isRemote:YES position:-1];
    }else{
        NSLog(@"Network not reachable -- aborting launch stream.");
        ret=FALSE;
    }
    return ret;
}

- (BOOL)startPlayingRemoteFile:(NSString*)file position:(int)position{
    BOOL ret=TRUE;
    if([file hasPrefix:@"file:///"] || [mNetworkStatus currentReachabilityStatus] != NotReachable){
        [self startPlayingInternal:file isRemote:YES position:position];
    }else{
        NSLog(@"Network not reachable -- aborting launch remote file.");
        ret=FALSE;
    }
    return ret;
}

- (BOOL)startPlayingLocalFile:(NSString*)file position:(int)position{
    BOOL ret=TRUE;
    
    if([[NSFileManager defaultManager] fileExistsAtPath:file]){
        [self startPlayingInternal:file isRemote:NO position:position];
    }else{
        NSLog(@"Local file doesn't exist -- aborting launch local file.");
        ret=FALSE;
    }
    return ret;
}


- (void)startPlayingInternal:(NSString*)file isRemote:(BOOL)isRemote position:(int)position {
    
    if ( mFile!=nil && ![file isEqualToString:mFile] && self.mPRXBasePlayer) {
        NSLog(@"Playing new audio -- stopping previous audio first");
        [self stopPlaying];
        mFile=[[NSString alloc]initWithString:file];
    } else if ( self.mPRXBasePlayer && ( [self.mPRXBasePlayer isPlayingAtPositiveRate] || [self.mPRXBasePlayer isPaused])){
        NSLog(@"Already playing the same file -- continuing");
    } else if ( self.mPRXBasePlayer && mFile!=nil && [file isEqualToString:mFile] &&  ![self.mPRXBasePlayer isPlayingAtPositiveRate]){
        NSLog(@"Restarting same audio after interruption");
        // restart the same stream
        // most likely scenario
        // - recovering from network drops
        // - audio interrupted by another audio-playing app
        [self stopPlaying];
         mFile=[[NSString alloc]initWithString:file];
    } else if (file != nil){
        NSLog(@"No audio playing -- starting");
        mFile=[[NSString alloc]initWithString:file];
    } else {
        NSLog(@"Nil file parameter passed into function--this shouldn't happen!");
        // doing this to prevent a crash -- need to figure out how to handle this better... should respond with an error
        mFile=@"";
    }
    
    if(!self.mPRXBasePlayer){
        NSLog(@"Creating PRXBasePlayer");
        self.mPRXBasePlayer = [[NYPRPlayer alloc] initWithCDVReachability:mNetworkStatus];
        if( position == -1){
            mCurrentlyPlaying = [[NYPRStream alloc] initWithURL:mFile];
        } else if( isRemote ){
            mCurrentlyPlaying = [[NYPROnDemand alloc] initWithURL:mFile position:position];
        } else {
            mCurrentlyPlaying = [[NYPROnDemand alloc] initWithFile:mFile position:position];
        }
        [self.mPRXBasePlayer addObserver:self persistent:TRUE];
        [self.mPRXBasePlayer setObserver:self];
        [self.mPRXBasePlayer loadPlayable:mCurrentlyPlaying ];
        
        [self audioStateDidChangeInternal:MEDIA_STARTING];
    }
    
    [self.mPRXBasePlayer play];    
}

- (void)togglePlayPause{
    [self.mPRXBasePlayer togglePlayPause];
}


- (void)pausePlaying{
    if( self.mPRXBasePlayer!=nil ){
        NSLog(@"Pausing Stream");
        [self.mPRXBasePlayer pause];
    }
}

- (void)unpausePlaying{
    NSLog(@"Resuming/Unpausing Stream");
    [self startPlayingStream:mFile];
}

- (void)stopPlaying{
    if( self.mPRXBasePlayer!=nil ){
        NSLog(@"Stopping Stream");
        [self stopAndTeardownAudioPlayer];
    }else{
        [self audioStateDidChangeInternal:MEDIA_STOPPED];
    }
}


- (void)setAudioInfo:(NSString*)title artist:(NSString*)artist artwork:(NSString*)artwork{

    [mPRXBasePlayer setAudioInfo:title artist:artist artwork:artwork];
    
    //[self refreshLockScreen];
}

-(void) audioStateDidChangeInternal:(int) state
{
    NSString * description=nil;
    
    mLastKnownState = state;
    
    switch (state) {
        case MEDIA_NONE:
            description = @"MEDIA_NONE";
            break;
        case MEDIA_STARTING:
            description = @"MEDIA_STARTING";
            break;
        case MEDIA_RUNNING:
            description = @"MEDIA_RUNNING";
            break;
        case MEDIA_PAUSED:
            description = @"MEDIA_PAUSED";
            break;
        case MEDIA_STOPPED:
            description = @"MEDIA_STOPPED";
            break;
        case MEDIA_LOADING:
            description = @"MEDIA_LOADING";
            break;
        case MEDIA_COMPLETED:
            description = @"MEDIA_COMPLETED";
            break;
        case MEDIA_PAUSING:
            description = @"MEDIA_PAUSING";
            break;
        case MEDIA_STOPPING:
            description = @"MEDIA_STOPPING";
            break;
        default:
            description=@"Unknown State";
            mLastKnownState=MEDIA_NONE;
            break;
    }
    
    NSLog(@"PRXPlayer Plugin state is %@", description);
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInteger:mLastKnownState], @"status",
      description, @"description",
      nil];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"AudioStreamUpdateNotification"
     object:self
     userInfo:dict];
    
    //if ( state==MEDIA_RUNNING){
    //    [self refreshLockScreen];
    //}
}

- (void) onRemoteControlEvent:(NSNotification *) notification
{
    if ([[notification name] isEqualToString:@"RemoteControlEventNotification"]){
        NSDictionary *dict = [notification userInfo];
        NSNumber * buttonId = [dict objectForKey:(@"buttonId")];
        
        switch ([buttonId intValue]){
            case UIEventSubtypeRemoteControlTogglePlayPause:
                NSLog(@"Remote control toggle play/pause!");
                [self togglePlayPause];
                break;
                
            case UIEventSubtypeRemoteControlPlay:
                NSLog(@"Remote control play!");
                [self unpausePlaying];
                break;
            
            case UIEventSubtypeRemoteControlPause:
                NSLog(@"Remote control toggle pause!");
                [self pausePlaying];
                break;
            
            case UIEventSubtypeRemoteControlStop:
                NSLog(@"Remote control stop!");
                [self pausePlaying];
                break;
            
            case UIEventSubtypeRemoteControlNextTrack:
                NSLog(@"Remote control next track");
                
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"AudioSkipNextNotification"
                 object:self
                 userInfo:nil];
                
                break;
            
            case UIEventSubtypeRemoteControlPreviousTrack:
                NSLog(@"Remote control previous track!");
                
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:@"AudioSkipPreviousNotification"
                 object:self
                 userInfo:nil];
                
                break;
            
            case UIEventSubtypeRemoteControlBeginSeekingBackward:
                NSLog(@"Remote control begin seeking backward!");
                break;
                
            case UIEventSubtypeRemoteControlEndSeekingBackward:
                NSLog(@"Remote control end seeking backward!");
                break;
                
            case UIEventSubtypeRemoteControlBeginSeekingForward:
                NSLog(@"Remote control begin seeking forward!");
                break;
                
            case UIEventSubtypeRemoteControlEndSeekingForward:
                NSLog(@"Remote control end seeking forward!");
                
                break;
                
            default:
                
                NSLog(@"Remote control unknown!");
                break;
        }
    }
}

-(void) stopAndTeardownAudioPlayer
{
    if (self.mPRXBasePlayer){
        [self.mPRXBasePlayer stop];
        //[self.mPRXBasePlayer release];
        self.mPRXBasePlayer = nil;
    }
    
    if (mCurrentlyPlaying!=nil){
        //[mCurrentlyPlaying release];
        mCurrentlyPlaying=nil;
    }
    
    if (mFile!=nil){
        //[mFile release];
        mFile=nil;
    }

}



-(void) dealloc
{
    [self stopAndTeardownAudioPlayer];

    // unsubscribe from remote control notifications?
    
    //[super dealloc];
}




-(void)updateProgress
{

    if( self.mPRXBasePlayer ){
        // update lock screen
        [self.mPRXBasePlayer refreshMetadata];
        
        int duration=0;
        int progress=0;
        int available=0;
        if( self.mPRXBasePlayer.currentPlayable ){
            duration = (int) CMTimeGetSeconds(self.mPRXBasePlayer.player.currentItem.duration);
            progress = (int) CMTimeGetSeconds(self.mPRXBasePlayer.player.currentItem.currentTime);
            available = [self.mPRXBasePlayer availableDuration];
            
            if(duration<0){
                duration=0;
            }
            
            if ( ! [self.mPRXBasePlayer.currentPlayable isStream] && [self.mPRXBasePlayer isPlayingAtPositiveRate]) {
                self.mPRXBasePlayer.currentPlayable.playbackCursorPosition = progress;
            }
        }
        
        long progressLong=(long) (progress*1000);
        long durationLong=(long) (duration*1000);
        long availableLong=(long)(available*1000);
        
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithLong:progressLong], @"progress",
                              [NSNumber numberWithLong:durationLong], @"duration",
                              [NSNumber numberWithLong:availableLong], @"available"
                              , nil];
        
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"AudioProgressNotification"
         object:self
         userInfo:dict];

    }
}

-(void) getAudioState
{
    [self audioStateDidChangeInternal:mLastKnownState];
}

#pragma mark Callbacks

- (void)observedPlayerStatusDidChange:(AVPlayer*)sender {
    
    if (![self.mPRXBasePlayer isPlayingAtPositiveRate] &&
        ([self.mPRXBasePlayer isPlayingAtPositiveRate] || [self.mPRXBasePlayer isBuffering]) ){
        
        [self audioStateDidChangeInternal:MEDIA_STARTING];
    }
    
    if( !self.mPRXBasePlayer.currentPlayable ){
        mLastKnownState = MEDIA_NONE;
    }
}

- (void)observedPlayerDidObservePeriodicTimeInterval:(AVPlayer*)sender {
    [self updateProgress];
}

- (void)observedPlayerDidObserveLongPeriodicTimeInterval:(AVPlayer *)player {
}

- (void) observedNYPRPlayerDidCompleteFile{
    
    
    NSLog(@"observedNYPRPlayerDidCompleteFile");
    NSLog(@"progress: %f", CMTimeGetSeconds(self.mPRXBasePlayer.player.currentItem.currentTime));
    NSLog(@"duration: %f", CMTimeGetSeconds(self.mPRXBasePlayer.player.currentItem.duration));
    
    int duration = (int) CMTimeGetSeconds(self.mPRXBasePlayer.player.currentItem.duration);
    if (duration>0){
        NSLog(@"On-demand completed. Sending MEDIA_STOPPED, then MEDIA_COMPLETED event.");
        [self audioStateDidChangeInternal:MEDIA_STOPPED];
        [self audioStateDidChangeInternal:MEDIA_COMPLETED];
    } else {
        NSLog(@"Stream stopped. Sending MEDIA_STOPPED");
        [self audioStateDidChangeInternal:MEDIA_STOPPED];
    }
}

- (void) observedNYPRPlayerDidStop{
    [self audioStateDidChangeInternal:MEDIA_STOPPED];
}

- (void) observedNYPRPlayerDidStart {
    //if(mLastKnownState!=MEDIA_RUNNING){
        [self audioStateDidChangeInternal:MEDIA_RUNNING];
    //}
}

- (void) observedNYPRPlayerDidPause {
    [self audioStateDidChangeInternal:MEDIA_PAUSED];
}


- (void)seekInterval:(NSInteger) interval
{
    if( interval > 0 ){
        [self.mPRXBasePlayer skipForward:(interval / 1000)];
    }else if (interval < 0) {
        [self.mPRXBasePlayer skipBack:((-1 * interval)/1000)];
    }
}

- (void)seekTo:(NSInteger) position
{
    [self.mPRXBasePlayer skipTo:(position/1000)];
}
@end

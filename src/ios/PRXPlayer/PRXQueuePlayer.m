//
//  PRXAudioPlayer.m
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

#import "PRXQueuePlayer.h"
#import "PRXPlayer_private.h"

@implementation PRXQueuePlayer

- (id)init {
    self = [super init];
    if (self) {
        _queue = [[PRXPlayerQueue alloc] init];
        self.queue.delegate = self;
    }
    return self;
}

- (void)loadAndPlayPlayable:(id<PRXPlayable>)playable {
    if ([self queueContainsPlayable:playable]) {
        self.queue.position = [self nextQueuePositionForPlayable:playable];
        [super loadAndPlayPlayable:playable];
    } else {
        if (playable) {
            [self enqueueAfterCurrentPosition:playable];
        }
      
        if ([self queueContainsPlayable:playable]) {
            [self loadAndPlayPlayable:playable];
        }
    }
}

- (void)play {
    if (self.queue.isEmpty) {
        [super play];
    } else {
        if (self.queue.position == NSNotFound) {
            [self moveToQueuePosition:0];
        }
        [self playPlayable:self.queue[self.queue.position]];
    }
}

- (void) playerItemStatusDidChange:(NSDictionary*)change {
    NSUInteger keyValueChangeKind = [change[NSKeyValueChangeKindKey] integerValue];
    
    if (keyValueChangeKind == NSKeyValueChangeSetting && self.player.currentItem.status == AVPlayerStatusFailed) {
        PRXLog(@"Player status failed %@", self.player.currentItem.error);
        // the AVPlayer has trouble switching from stream to file and vice versa
        // if we get an error condition, start over playing the thing it tried to play.
        // Once a player fails it can't be used for playback anymore!
        waitingForPlayableToBeReadyForPlayback = NO;
        
        if (retryCount < self.retryLimit) {
            [super playerItemStatusDidChange:change];
        } else {
            [self reportPlayerStatusChangeToObservers];
            [self seekForward];
        }
    } else {
        [super playerItemStatusDidChange:change];
    }
    
}

#pragma mark - Next and previous

- (BOOL)hasPrevious {
    return (self.queue.position != NSNotFound && self.queue.position > 0 && self.queue.count > 1);
}

- (BOOL)hasNext {
    return (self.queue.position != NSNotFound && self.queue.position < (self.queue.count - 1));
}

- (NSUInteger)previousPosition {
    return self.hasPrevious ? (self.queue.position - 1) : NSNotFound;
}

- (NSUInteger)nextPosition {
    return self.hasNext ? (self.queue.position + 1) : NSNotFound;
}

#pragma mark - Queue movement

- (BOOL)canMoveToQueuePosition:(NSUInteger)position {
    if (self.queue.count == 0) { return NO; }
    
    return (position <= (self.queue.count - 1));
}

- (void)moveToQueuePosition:(NSUInteger)position {
    if ([self canMoveToQueuePosition:position]) {
        self.queue.position = position;
    }
}

- (void) seekToQueuePosition:(NSUInteger)position {
    if ([self canMoveToQueuePosition:position]) {
    	[self moveToQueuePosition:position];
    	[self preparePlayable:self.queue[self.queue.position]];
    }
}

- (void) seekForward {
    if (self.hasNext) {
        [self seekToQueuePosition:self.nextPosition];
    }
}

- (void) seekBackward {
    if (self.hasPrevious) {
    	[self seekToQueuePosition:self.previousPosition];
    }
}

- (void)moveToPrevious {
    if (self.hasPrevious) {
        [self moveToQueuePosition:self.previousPosition];
    }
}

- (void)moveToNext {
    if (self.hasNext) {
        [self moveToQueuePosition:self.nextPosition];
    }
}

#pragma mark - Queue manipulation

- (void)enqueue:(id<PRXPlayable>)playable atPosition:(NSUInteger)position {
    [self.queue insertObject:playable atIndex:position];
    
    if (!self.currentPlayable) {
        if (self.queue.position == NSNotFound) {
            self.queue.position = 0;
        }

        [self loadPlayable:self.queue[self.queue.position]];
    }
}

- (void)enqueue:(id<PRXPlayable>)playable {
    [self enqueue:playable atPosition:self.queue.count];
}

- (void)enqueueAfterCurrentPosition:(id<PRXPlayable>)playable {
    int position = (self.queue.count == 0 ? 0 : (self.queue.position + 1));
    [self enqueue:playable atPosition:position];
}

- (void)dequeueFromPosition:(NSUInteger)position {
    [self.queue removeObjectAtIndex:position];
}

- (void)dequeue:(id<PRXPlayable>)playable {
    int position = [self firstQueuePositionForPlayable:playable];
    if (position != NSNotFound) {
        [self dequeueFromPosition:position];
    }
}

- (void)movePlayableFromPosition:(NSUInteger)position toPosition:(NSUInteger)newPosition {
    if ([self canMoveToQueuePosition:position] && [self canMoveToQueuePosition:newPosition]) {
        // If the current item is being moved, we
        // want to make sure the position in the queue
        // follows it.
        BOOL moveQueuePositionToNewPosition = (position == self.queue.position);
        
        id<PRXPlayable> playable = self.queue[position];
        
        [self.queue removeObjectAtIndex:position];
        [self.queue insertObject:playable atIndex:newPosition];
        
        if (moveQueuePositionToNewPosition) {
            self.queue.position = newPosition;
        }
    }
}

- (void)requeue:(id<PRXPlayable>)playable atPosition:(NSUInteger)position {
    int index = [self firstQueuePositionForPlayable:playable];
    if (index != NSNotFound) {
        [self movePlayableFromPosition:index toPosition:position];
    }
}

- (void)enqueuePlayables:(NSArray*)playables atPosition:(NSUInteger)position {
    NSUInteger iPosition = position;
    
    for (id<PRXPlayable> playable in playables) {
        [self enqueue:playable atPosition:iPosition];
        iPosition++;
    }
}

- (void)enqueuePlayables:(NSArray*)playables {
    [self enqueuePlayables:playables atPosition:self.queue.count];
}

- (void)emptyQueue {
    [self.queue removeAllObjects];
    
    if (self.player.rate != 0.0f) {
        [self enqueue:self.currentPlayable];
        [self reportPlayerStatusChangeToObservers];
    }
}

#pragma mark - Queue queries

- (BOOL)queueContainsPlayable:(id<PRXPlayable>)playable {
    return ([self firstQueuePositionForPlayable:playable] != NSNotFound);
}

- (id<PRXPlayable>)playableAtQueuePosition:(NSUInteger)position {
    return [self.queue objectAtIndex:position];
}

- (id)playableAtCurrentQueuePosition {
    return [self.queue objectAtIndex:self.queue.position];
}

- (NSUInteger)firstQueuePositionForPlayable:(id<PRXPlayable>)playable {
    return [self.queue indexOfObjectPassingTest:^BOOL(id<PRXPlayable> aPlayable, NSUInteger idx, BOOL *stop) {
        return [self playable:aPlayable isEqualToPlayable:playable];
    }];
}

- (NSUInteger)nextQueuePositionForPlayable:(id<PRXPlayable>)playable {
    NSUInteger position;
    
    position = [self.queue indexOfObjectPassingTest:^BOOL(id<PRXPlayable> aPlayable, NSUInteger idx, BOOL* stop) {
        return ([self playable:aPlayable isEqualToPlayable:playable] && idx >= self.queue.position);
    }];
    
    if (position == NSNotFound) {
        position = [self firstQueuePositionForPlayable:playable];
    }
    
    return position;
}

- (NSIndexSet*)allQueuePositionsForPlayable:(id<PRXPlayable>)playable {
    return [self.queue indexesOfObjectsPassingTest:^BOOL(id<PRXPlayable>aPlayable, NSUInteger idx, BOOL *stop) {
        return [self playable:aPlayable isEqualToPlayable:playable];
    }];
}

#pragma mark - Remote control

- (void)remoteControlReceivedWithEvent:(UIEvent*)event {
    [super remoteControlReceivedWithEvent:event];
    
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlNextTrack:
            [self seekForward];
            break;
		case UIEventSubtypeRemoteControlPreviousTrack:
            [self seekBackward];
			break;
		default:
			break;
	}
}

- (NSDictionary*)MPNowPlayingInfoCenterNowPlayingInfo {
    NSMutableDictionary *info = super.MPNowPlayingInfoCenterNowPlayingInfo.mutableCopy;
    
    if (!info[MPMediaItemPropertyAlbumTrackNumber]) {
        NSUInteger position = (self.queue.position == NSNotFound ? 0 : self.queue.position);
        NSUInteger count = (position + 1);
        
        info[MPMediaItemPropertyAlbumTrackNumber] = @(count);
    }
    
    if (!info[MPMediaItemPropertyAlbumTrackCount]) {
        info[MPMediaItemPropertyAlbumTrackCount] = @(self.queue.count);
    }
    
    return info;
}

#pragma mark - PRXAudioQueue delegate

- (void) queueDidChange:(PRXPlayerQueue*)queue {    
    [self reportPlayerStatusChangeToObservers];
}

#pragma mark -- Overrides

- (void) playerItemDidPlayToEndTime:(NSNotification*)notification {
    [super playerItemDidPlayToEndTime:notification];
    [self seekForward];
}

@end

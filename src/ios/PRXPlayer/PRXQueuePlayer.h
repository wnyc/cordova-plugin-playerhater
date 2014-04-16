//
//  PRXAudioPlayer.h
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
#import "PRXPlayerQueue.h"

@interface PRXQueuePlayer : PRXPlayer<PRXPlayerQueueDelegate>

@property (strong, nonatomic, readonly) PRXPlayerQueue *queue;

@property (nonatomic, readonly) BOOL hasNext;
@property (nonatomic, readonly) BOOL hasPrevious;

@property (nonatomic, readonly) NSUInteger previousPosition;
@property (nonatomic, readonly) NSUInteger nextPosition;

- (BOOL) canMoveToQueuePosition:(NSUInteger)position;
- (void) moveToQueuePosition:(NSUInteger)position;
- (void) seekToQueuePosition:(NSUInteger)position;

- (void) seekForward;
- (void) seekBackward;

- (void) enqueue:(id<PRXPlayable>)playable; 
- (void) enqueue:(id<PRXPlayable>)playable atPosition:(NSUInteger)position;
- (void) enqueueAfterCurrentPosition:(id<PRXPlayable>)playable;

- (void) dequeue:(id<PRXPlayable>)playable;
- (void) dequeueFromPosition:(NSUInteger)position;
- (void) requeue:(id<PRXPlayable>)playable atPosition:(NSUInteger)position;
- (void) movePlayableFromPosition:(NSUInteger)inPosition toPosition:(NSUInteger)outPosition;

- (void) enqueuePlayables:(NSArray *)playables;
- (void) enqueuePlayables:(NSArray *)playables atPosition:(NSUInteger)position; 

- (void) emptyQueue;

- (BOOL) queueContainsPlayable:(id<PRXPlayable>)playable;
- (NSUInteger) firstQueuePositionForPlayable:(id<PRXPlayable>)playable;
- (NSUInteger) nextQueuePositionForPlayable:(id<PRXPlayable>)playable;
- (NSIndexSet *) allQueuePositionsForPlayable:(id<PRXPlayable>)playable;
- (id<PRXPlayable>) playableAtCurrentQueuePosition;
- (id<PRXPlayable>) playableAtQueuePosition:(NSUInteger)position;

@end

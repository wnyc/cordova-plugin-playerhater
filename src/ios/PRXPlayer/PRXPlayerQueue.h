//
//  PRXPlayerQueue.h
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

/**
 `PRXPlayerQueue` is an array-like collection that is used to manage a list of playble objects intended for use in a `PRXQueuePlayer`. It implements the NSArray primative methods and all methods NSMutableArray requires for subclassing. Any other NSArray or NSMutableArray methods may not work as expected if used directly on a `PRXPlayerQueue`.
 
 ## Cursor
 
 The main difference between the `PRXAudioQueue` and a standard `NSMutableArray` is the cursor that is maintained by `PRXAudioQueue` to signify a position within the queue representing the currently playing item. The cursor is specifically managed such that it will never point to a position outside the current range of the collection. If something tries to move the cursor beyond the bounds of the collection, it will be set to the closet valid value. 
 
 When the cursor is not defined, it will return `NSNotFound`. Any time the queue is empty the cursor will return `NSNotFound`. It is possible for the queue to include one or more items and have an undefined cursor.
 
 ## Intended use
 
 The only place a `PRXPlayerQueue` should be interacted with is inside a `PRXQueuePlayer` subclass. Application code is not intended to be aware of this class. Even though the `cursor` is exposed, it should not be get or set outside of a `PRXQueuePlayer` or subclass.
 
 ## Delegate
 
 When a delegate has been set for a `PRXAudioQueue`, it will be notified of changes to the following conditions of the queue:
 
 - The `cursor` position
 - The size of the queue
 - The position of objects within the queue
 */

@protocol PRXPlayerQueueDelegate;

@interface PRXPlayerQueue : NSMutableArray

@property (nonatomic, weak) id<PRXPlayerQueueDelegate> delegate;
@property (nonatomic) NSUInteger position;

@property (nonatomic, readonly) BOOL isEmpty;


///---------------------------------------
/// @name NSArray primative methods
///---------------------------------------

/**
 Returns the object located at _index_.
 
 @param index An index within or outside the bounds of the array.
 
 @return The object located at _index_, or `nil`.
 
 @discussion If _index_ is beyond the end of the array `nil` is returned.
 */
- (id)objectAtIndex:(NSUInteger)index;

///---------------------------------------
/// @name NSMutableArray methods
///---------------------------------------

/**
 Inserts the given object at the specified index of the mutable ordered set.
 
 @discussion Unlike `insertObject:atIndex:` for `NSMutableArray`, if _idx_ is greater than the number of elements in the queue _object_ will be inserted at the end of the collection.
 
 If the index is less than or equal to the current queue position, the position will be incremented so the selected element does not change.
 */
- (void)insertObject:(id)anObject atIndex:(NSUInteger)index;

/**
 Removes the object at _index_.
 
 @discussion If the queue becomes empty after remove the object, the queue's position becomes `NSNotFound`.
 
 If the index is less than the current queue position, the position will be decremented so the selected element does not change.
 */
- (void)removeObjectAtIndex:(NSUInteger)index;

@end

/**
 The `PRXPlayerQueueDelegate` protocol defines a method that allows an object, usually a `PRXQueuePlayer`, to be notified when the queue changes.
 */
@protocol PRXPlayerQueueDelegate <NSObject>

/**
 Tells the delegate when the queue or queue position changes.
 
 @param queue The queue object in which the change occured
 
 @discussion The delegate typically implements this method to respond to changes resulting from user actions, or from triggered internally within the queue or the queue player.
 */
- (void) queueDidChange:(PRXPlayerQueue *)queue;

@end

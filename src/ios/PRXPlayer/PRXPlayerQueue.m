//
//  PRXPlayerQueue.m
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

#import "PRXPlayerQueue.h"

@interface PRXPlayerQueue ()

@property (nonatomic, strong) NSMutableArray *collection;

@property (nonatomic) NSUInteger lastPosition;

- (void) incrementPosition;
- (void) decrementPosition;

- (void) notifyDelegate; 

@end

@implementation PRXPlayerQueue

- (id) init {
    self = [super init];
    if (self) {
        self.collection = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

#pragma mark - Backing collection

- (void)setCollection:(NSMutableArray*)collection {
    _collection = collection;
    self.position = (collection.count == 0 ? NSNotFound : 0);
}

- (BOOL)isEmpty {
    return (self.count == 0);
}

#pragma - Position manipulation

- (void)setPosition:(NSUInteger)position {
    _position = ((position == NSNotFound || self.isEmpty) ? NSNotFound : MAX(0, MIN(position, self.lastPosition)));
    [self notifyDelegate];
}

- (void)incrementPosition {
    self.position = (self.position == NSNotFound ? 0 : (self.position + 1));
}

- (void)decrementPosition {
    self.position = (self.position == NSNotFound ? NSNotFound : (self.position - 1));;
}

- (NSUInteger)lastPosition {
    return (self.count == 0 ? NSNotFound : (self.count - 1));
}


#pragma mark - NSArray primative methods

- (NSUInteger)count {
    return self.collection.count;
}

- (id)objectAtIndex:(NSUInteger)index {
    if (index != NSNotFound && index < self.collection.count) {
        return [self.collection objectAtIndex:index];
    }
    
    return nil;
}

#pragma mark - NSMutableArray methods

- (void)insertObject:(id)anObject atIndex:(NSUInteger)index {
    [self.collection insertObject:anObject atIndex:MIN(index, self.collection.count)];
    
    // TODO If things are allowed to play without being in the queue
    // (like if the current item is dequeued), incrementing the counter
    // here when NSNotFound could be bad
    if (index <= self.position || self.position == NSNotFound) {
        // If an item is inserted before the current item,
        // shift the cursor to follow the current item.
        // Or if the cursor hasn't been set, increment it
        // to get it to 0.
        [self incrementPosition];
    }
    
    [self notifyDelegate];
}

- (void)removeObjectAtIndex:(NSUInteger)index {
    if (index >= self.collection.count) { return; }
    
    [self.collection removeObjectAtIndex:index];
    
    if (self.position != NSNotFound) {
        if (index < self.position) {
            // When removing an item below the current cursor,
            // the current item will shift down one, so we need
            // to make the cursor follow it
            [self decrementPosition];
        }
        
        if (self.position > self.lastPosition) {
            // If the cursor ever gets out of bounds, move it
            // back in bounds. This can happen when the cursor
            // is on the last item, and it is removed.
            self.position = self.lastPosition;
        }    
    }
    
    if (self.isEmpty) {
        self.position = NSNotFound;
    }
    
    [self notifyDelegate];
}

- (void)addObject:(id)anObject {
    [self.collection addObject:anObject];
    
    [self notifyDelegate];
}

- (void)removeAllObjects {
    [self.collection removeAllObjects];
    self.position = NSNotFound;
    
    [self notifyDelegate];
}

- (void)removeLastObject {
    [self removeObjectAtIndex:self.lastPosition];
}

#pragma mark - Delegate and observers

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    [self notifyDelegate];
}

- (void)notifyDelegate {
    if (self.delegate) {
        [self.delegate queueDidChange:self];
    }
}

@end

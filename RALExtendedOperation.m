/*
 
 Copyright (c) 2015-2017 PowerIT, Inc. Company
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

#import "RALExtendedOperation.h"

@interface RALExtendedOperation ()
@property (nonatomic, assign) BOOL isExecuting;
@property (nonatomic, assign) BOOL isFinished;

@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, copy) void (^block)();
@end

@implementation RALExtendedOperation

-(instancetype)initWithBlock:(void (^)())block extensionDuration:(NSTimeInterval)duration queue:(dispatch_queue_t)queue{
    if (self = [super init]){
        self.block = block;
        self.duration = duration;
        self.queue = queue;
    }
    return self;
}

-(BOOL)isAsynchronous{
    return YES;
}


-(void)setFinished{
    [self willChangeValueForKey:@"isFinished"];
    self.isFinished = YES;
    [self didChangeValueForKey:@"isFinished"];
}

-(void)setExecuting:(BOOL)exec{
    [self willChangeValueForKey:@"isExecuting"];
    self.isExecuting = exec;
    [self didChangeValueForKey:@"isExecuting"];
}

-(void)start{
    if (self.cancelled){
        return;
    }
    [self setExecuting:YES];

    dispatch_async(self.queue, ^{
        self.block();
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.duration * NSEC_PER_SEC)), self.queue, ^{
            [self setExecuting:NO];
            [self setFinished];
        });
    });
}

@end

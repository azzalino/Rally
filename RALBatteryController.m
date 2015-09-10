/*  

Copyright (c) 2015 PowerIT, Inc. Company

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

#import "RALBatteryController.h"
#import <ExternalAccessory/ExternalAccessory.h>

@interface RALBatteryController()<NSStreamDelegate>
{
    BOOL _isCharging;
    BOOL _isConnected;
    
}

@property (strong, nonatomic) EAAccessory *currentAccessory;
@property (strong, nonatomic) EASession *session;

@property (nonatomic, assign) NSStreamEvent event;

@end


@implementation RALBatteryController

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnectNotification:) name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnectNotification:) name:EAAccessoryDidDisconnectNotification object:nil];
        
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
        if(!self.connected) for(EAAccessory *accessory in [[EAAccessoryManager sharedAccessoryManager] connectedAccessories])
        {
            [self accessoryDidConnectNotification:[NSNotification notificationWithName:EAAccessoryDidConnectNotification object:self userInfo:@{EAAccessoryKey:accessory}]];
        }                                    
    }
    return self;
}

/* This should not happen under normal circumstances, if e.g. sbd is debugging or modifying our code, however, let's make sure that all gets cleaned up ok */

- (void)dealloc
{
    [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidDisconnectNotification object:nil];
    [self.session.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.session.outputStream close];

}



#pragma mark - External interface

- (BOOL)connected
{
    return _isConnected;
}

- (BOOL)charging
{
    return _isCharging;
}

- (BOOL) startCharging
{
    return [self setCharging:YES];
}

- (BOOL) stopCharging
{
    return [self setCharging:NO];
}

- (void)start
{
    /* dummy, just to make sure sbd runs + sharedController */
}

+ (instancetype) sharedController
{
    static dispatch_once_t onceToken;
    static RALBatteryController *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [RALBatteryController new];
    });
    return sharedInstance;
}
#pragma mark - Helpers

- (BOOL) setCharging: (BOOL) on
{
    if(self.currentAccessory == nil) return NO;
    if(self.event!=NSStreamEventHasSpaceAvailable) return NO;
    if(!_isConnected) return NO;
    if(_isCharging && on) return NO;
    if(!_isCharging && !on) return NO;
    
    
    uint8_t byteBuffer[1];
    byteBuffer[0] = _isCharging ? 'c' : 'b';
    
    [self.session.outputStream write:byteBuffer maxLength:1];
    _isCharging = on;
    return YES;
}



#pragma mark - Notifications

- (void) accessoryDidConnectNotification : (NSNotification *) notification
{
    EAAccessory *accessory = notification.userInfo[EAAccessoryKey];
    if ([[accessory.protocolStrings filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%@ in self",@"com.rallypwr."]] count])
    {
        self.currentAccessory = accessory;
        self.session = [[EASession alloc] initWithAccessory:accessory forProtocol:accessory.protocolStrings[0]];
        
        if (self.session)
        {
            [[self.session outputStream] open];
            [self.session.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                                 forMode:NSDefaultRunLoopMode];
            self.session.outputStream.delegate = self;
            _isConnected = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)RALBatteryConnectedNotification object:self];
        }
        else
        {
            self.currentAccessory = nil;
            _isConnected = NO;
        }
    }
}

- (void) accessoryDidDisconnectNotification : (NSNotification *) notification
{
    if([notification.userInfo[EAAccessoryKey] isEqual:self.currentAccessory])
    {
        self.currentAccessory = nil;
        [self.session.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.session.outputStream close];
        
        self.session = nil;
        _isCharging = NO;
        _isConnected = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)RALBatteryDisconnectedNotification object:self];
    }
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    self.event = eventCode;
}



@end

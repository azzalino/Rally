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
#import "RALExtendedOperation.h"

static uint8_t const kRALBatteryControllerSignalStopAndReset = 'c';
static uint8_t const kRALBatteryControllerSignalStart = 'b';
static uint8_t const kRALBatteryControllerSignalWarningStart = 'd';
static uint8_t const kRALBatteryControllerSignalWarningStop = 'g';
static uint8_t const kRALBatteryControllerSignalForeground = 'e';
static uint8_t const kRALBatteryControllerSignalBackground = 'h';


static NSTimeInterval const kRALBatteryControllerInitialCommunicationDelay = 0.5;
static NSTimeInterval const kRALBatteryControllerBackgroundEventDelay = 0.5;


@interface RALBatteryController()<NSStreamDelegate>
{
    BOOL _isCharging;
    BOOL _isConnected;
    BOOL _autoconnectMode;
}


@property (strong, nonatomic) EASession *session;

@property (nonatomic, assign) NSStreamEvent event;
// queue used to send raw bytes to the battery
@property (nonatomic, strong) NSOperationQueue *streamCommunicationQueue;

@end


@implementation RALBatteryController
@synthesize currentAccessory = _currentAccessory;

#pragma mark - Lifecycle

- (void)initialize {
    /* Dummy method. The actual initialization is in the sharedController */
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.streamCommunicationQueue = [[NSOperationQueue alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnectNotification:) name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnectNotification:) name:EAAccessoryDidDisconnectNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminateNotification:) name:UIApplicationWillTerminateNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        
        
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.session.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.session.outputStream close];
}



#pragma mark - External interface


- (void)setAutoConnectMode:(BOOL)autoConnectMode {
    if(_autoConnectMode == autoConnectMode) return;
    _autoConnectMode = autoConnectMode;
    if (autoConnectMode) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryDidConnectNotification:) name:RALBatteryConnectedNotification object:nil];
        
            if(!self.connected) for(EAAccessory *accessory in [[EAAccessoryManager sharedAccessoryManager] connectedAccessories])
            {
                [self accessoryDidConnectNotification:[NSNotification notificationWithName:EAAccessoryDidConnectNotification object:self userInfo:@{EAAccessoryKey:accessory}]];
            }
            else
            {
                [self startCharging];
            }
        });
    }
    else
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:RALBatteryConnectedNotification object:nil];
        [self stopCharging];
    }
    
}

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

- (BOOL) sendWarning
{
    return [self sendCharacter: kRALBatteryControllerSignalWarningStart];
}

- (BOOL) sendStopChargingWithWarning
{
    return [self sendCharacter: kRALBatteryControllerSignalWarningStop];
}

- (BOOL) sendReset
{
    return [self sendCharacter: kRALBatteryControllerSignalStopAndReset];
}

/**
 Sends reset signal synchronously on a current thread
 */
- (void) sendResetImmediately
{
    [self sendCharacterImmediately: kRALBatteryControllerSignalStopAndReset];
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

- (BOOL) sendCharacter: (uint8_t)character{
    if (![self streamReadyToSend]){
        return NO;
    }
    
    // access to outputStream has to be only done from runloop that given stream is scheduled (here main queue)
    RALExtendedOperation *operation = [[RALExtendedOperation alloc] initWithBlock:^{
        [self sendCharacterImmediately:character];
    } extensionDuration:0.5 queue:dispatch_get_main_queue()];

    for (NSOperation *queueOperaion in [self.streamCommunicationQueue operations]) {
        [operation addDependency:queueOperaion];
    }
    
    [self.streamCommunicationQueue addOperation:operation];
    return YES;
}

- (void) sendCharacterImmediately: (uint8_t)character{
    uint8_t byteBuffer[1];
    byteBuffer[0] = character;
    
    [self.session.outputStream write:byteBuffer maxLength:1];
}

- (BOOL) setCharging: (BOOL) on
{
    if (![self streamReadyToSend]) return NO;
    if(_isCharging == on) return NO;
    
    
    [self sendCharacter: on ? kRALBatteryControllerSignalStart : kRALBatteryControllerSignalStopAndReset];
    [self willChangeValueForKey:@"charging"];
    _isCharging = on;
    [self willChangeValueForKey:@"charging"];
    return YES;
}

/**
 Informs if output stream is ready to send data to accessory

 @return YES for ready stream, NO otherwise
 */
- (BOOL) streamReadyToSend {
    if(self.currentAccessory == nil) return NO;
    if(self.event!=NSStreamEventHasSpaceAvailable) return NO;
    if(!_isConnected) return NO;
    
    return YES;
}

- (void) lockOutputStreamForDuration:(NSTimeInterval)delay{
    [self.streamCommunicationQueue addOperation:[[RALExtendedOperation alloc]initWithBlock:^{} extensionDuration:delay queue:dispatch_get_main_queue()]];
}

#pragma mark - Notifications

- (void) accessoryDidConnectNotification : (NSNotification *) notification
{
    EAAccessory *accessory = notification.userInfo[EAAccessoryKey];
    if ([[accessory.protocolStrings filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%@ in self",@"com.rallypwr."]] count])
    {
        [self willChangeValueForKey:@"currentAccessory"];
        _currentAccessory = accessory;
        [self didChangeValueForKey:@"currentAccessory"];
        self.session = [[EASession alloc] initWithAccessory:accessory forProtocol:accessory.protocolStrings[0]];
        
        if (self.session)
        {
            [self lockOutputStreamForDuration: kRALBatteryControllerInitialCommunicationDelay];
            
            [[self.session outputStream] open];
            [self.session.outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop]
                                                 forMode:NSDefaultRunLoopMode];
            self.session.outputStream.delegate = self;
            [self willChangeValueForKey:@"connected"];
            _isConnected = YES;
            [self didChangeValueForKey:@"connected"];
            [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)RALBatteryConnectedNotification object:self];
        }
        else
        {
           [self willChangeValueForKey:@"currentAccessory"];
            _currentAccessory = nil;
           [self didChangeValueForKey:@"currentAccessory"];
           [self willChangeValueForKey:@"connected"];
            _isConnected = NO;
           [self didChangeValueForKey:@"connected"];
        }
    }
}

- (void) accessoryDidDisconnectNotification : (NSNotification *) notification
{
    if([notification.userInfo[EAAccessoryKey] isEqual:self.currentAccessory])
    {
        [self.streamCommunicationQueue cancelAllOperations];
        
        [self willChangeValueForKey:@"currentAccessory"];
        _currentAccessory = nil;
        [self didChangeValueForKey:@"currentAccessory"];
        [self.session.outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.session.outputStream close];
        
        self.session = nil;
       [self willChangeValueForKey:@"connected"];
       [self willChangeValueForKey:@"charging"];
        _isCharging = NO;
        _isConnected = NO;
        [self didChangeValueForKey:@"connected"];
        [self didChangeValueForKey:@"charging"];

        [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)RALBatteryDisconnectedNotification object:self];
    }
}

- (void)applicationDidEnterBackgroundNotification: (NSNotification *) notification {
    [self lockOutputStreamForDuration:kRALBatteryControllerBackgroundEventDelay];
    
    [self sendCharacter: kRALBatteryControllerSignalBackground];
}

- (void)applicationWillEnterForegroundNotification: (NSNotification *) notification {
    [self sendCharacter: kRALBatteryControllerSignalForeground];
}

- (void) batteryDidConnectNotification: (NSNotification *) note
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startCharging];
    });
}

- (void) applicationWillTerminateNotification: (NSNotification *) note {
    // quickly send reset signal before termination
    [self sendResetImmediately];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    self.event = eventCode;
}


@end

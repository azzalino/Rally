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

#import <Foundation/Foundation.h>

/* The notifications are posted when battery is plugged in/out */

static const NSString *RALBatteryConnectedNotification = @"RALBatteryConnectedNotification";
static const NSString *RALBatteryDisconnectedNotification = @"RALBatteryDisconnectedNotification";


@interface RALBatteryController : NSObject

/// Boolean indicating if the battery is connected to the device
@property(nonatomic, readonly) BOOL connected;
/// Boolean indicating if the battery is charging the device
@property(nonatomic, readonly) BOOL charging;

/** Starts charging the device
  * @return YES if all went ok, otherwise NO
  */
- (BOOL) startCharging;

/** Stops charging the device
 * @return YES if all went ok, otherwise NO
 */
- (BOOL) stopCharging;

/// Returns the singleton instance. The class should be operated on as a singleton only.
+ (instancetype) sharedController;

/** Starts the manager. This should be run before any usage. It can be run many times, though. */
- (void) start;

@end

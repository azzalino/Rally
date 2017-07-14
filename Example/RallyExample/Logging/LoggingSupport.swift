//
//  LoggingSupport.swift
//  RallyExample
//
//  Created by Bartosz Polaczyk on 12/07/2017.
//  Copyright © 2017 Railwaymen. All rights reserved.
//

import Foundation
import CocoaLumberjack

func logInfo(_ text:String){
    DDLog.log(true, message: DDLogMessage(message: text, level: DDLogLevel.info, flag: DDLogFlag.info, context: 0, file: "", function: "", line: 0, tag: nil, options: DDLogMessageOptions.copyFile, timestamp: Date()))

}

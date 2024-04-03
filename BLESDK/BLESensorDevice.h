//
//  Sensors.h
//  BLESDK
//
//  Created by Tom on 2024/4/2.
//  Copyright © 2024 CoolTools. All rights reserved.
//

#ifndef BLESensorDevice_h
#define BLESensorDevice_h

#import <Foundation/Foundation.h>

@protocol BLESensorDevice

@property (readonly) NSArray* sensors;

- (BLESensor*)sensorWithName: (NSString*)sensorName;

- (void)switchSensor: (NSString*)sensorName onOff: (BOOL)on;

@end

#endif

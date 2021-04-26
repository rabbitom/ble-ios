//
//  BLESensor.h
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#ifndef BLESensor_h
#define BLESensor_h

#import "BLEDevice.h"

@interface BLESensor : BLEDevice

@property (readonly) NSDictionary* features;

@end

#endif /* BLESensor_h */

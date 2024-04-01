//
//  BLEUtility.h
//  BLESensor
//
//  Created by 郝建林 on 16/8/23.
//  Copyright © 2016年 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreBluetooth/CBManager.h>

@interface BLEUtility : NSObject

+ (NSString*)serviceName: (CBUUID*)serviceUUID;

+ (NSString*)centralState:(CBManagerState)state;

@end

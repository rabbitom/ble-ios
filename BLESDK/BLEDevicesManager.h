//
//  BLEDevicesManager.h
//  BLESensor
//
//  Created by 郝建林 on 16/8/16.
//  Copyright © 2016年 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface BLEDevicesManager : NSObject <CBCentralManagerDelegate>

+ (instancetype)sharedInstance;
+ (CBCentralManager*)central;

- (void)addDeviceClassFromFile: (NSString*)filePath;
- (void)addDeviceClass: (NSDictionary*)metadata;

@property (readonly) BOOL isScanning;
- (void)startScan;
- (void)stopScan;
//- (NSArray*)devicesOfClass: (NSString*)className sortBy: (NSString*)key max: (int)count;

- (id)findDevice: (NSUUID*)deviceId;

@property BOOL filterDeviceOfUnknownClass;

@end

//
//  BLEDevice.h
//  BLESensor
//
//  Created by 郝建林 on 16/8/16.
//  Copyright © 2016年 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "CSLDevice.h"

@interface BLEDevice : CSLDevice <CBPeripheralDelegate>
{
    NSMutableDictionary *advertisementData;
    NSDictionary *serviceData;
}
@property CBPeripheral *peripheral;
@property (readonly) NSDictionary *advertisementData;

@property (readonly) NSString *deviceKey;
@property (readonly) NSString *deviceName;
@property (readonly) NSArray *deviceInfo;
@property int rssi;

- (id)initWithPeripheral: (CBPeripheral*)peripheral advertisementData: (NSDictionary*)ad classMetadata: (NSDictionary*)classMetadata;
- (void)updateAdvertisementData: (NSDictionary*)ad;
- (void)updateServiceData;

- (BOOL)connect;
- (void)disconnect;
- (void)onConnected;
@property (readonly) BOOL isConnected;

- (void)writeData: (NSData*)data to: (NSString*)characteristicName;
- (void)readData: (NSString*)characteristicName;
- (void)startNotification: (NSString*)characteristicName;
- (void)stopNotification: (NSString*)characteristicName;
- (BOOL)isNofitying: (NSString*)characteristicName;
- (void)onReceivedData: (NSData*)data from: (NSString*)characteristicName;

@end

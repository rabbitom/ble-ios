//
//  BLEDevice.h
//  BLESensor
//
//  Created by 郝建林 on 16/8/16.
//  Copyright © 2016年 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface BLEDevice : NSObject <CBPeripheralDelegate>
{
    NSMutableDictionary *advertisementData;
    NSDictionary *metadata;
    NSDictionary *serviceData;
}
@property CBPeripheral *peripheral;
@property (readonly) NSDictionary *advertisementData;

@property (readonly) NSString *deviceKey;
@property int rssi;
@property (readonly) NSString *deviceDesc;

- (NSString*) deviceNameByDefault: (NSString*)defaultName;

@property (readonly) BOOL isConnected;

- (id)initWithPeripheral: (CBPeripheral*)peripheral advertisementData: (NSDictionary*)ad classMetadata: (NSDictionary*)classMetadata;
- (void)updateAdvertisementData: (NSDictionary*)ad;
- (void)updateServiceData;

- (void)connect;
- (void)disconnect;

- (void)onConnected;
- (void)onReceiveData: (NSData*)data forProperty: (NSString*)propertyName;
- (void)onValueChanged: (id)value ofProperty: (NSString*)propertyName;

- (void)writeData: (NSData*)data forProperty: (NSString*)propertyName;

- (void)setReady;

- (void)readData: (NSString*)propertyName;
- (void)startReceiveData: (NSString*)propertyName;
- (void)stopReceiveData: (NSString*)propertyName;
- (BOOL)isReceivingData: (NSString*)propertyName;

@end

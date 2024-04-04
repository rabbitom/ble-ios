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
    NSMutableDictionary *state;
}
@property CBPeripheral *peripheral;
@property (readonly) NSDictionary *advertisementData;

@property (readonly) NSString *deviceKey;
@property (readonly) NSString *deviceName;
@property (readonly) NSString *deviceDesc;
@property int rssi;

@property (readonly) BOOL isConnected;

@property (readonly) NSMutableDictionary *state;

- (id)initWithPeripheral: (CBPeripheral*)peripheral advertisementData: (NSDictionary*)ad classMetadata: (NSDictionary*)classMetadata;
- (void)updateAdvertisementData: (NSDictionary*)ad;
- (void)updateServiceData;

- (BOOL)connect;
- (void)disconnect;
- (void)onConnected;
- (void)onReady;

- (void)writeData: (NSData*)data to: (NSString*)characteristicName;
- (void)readData: (NSString*)characteristicName;
- (void)startReceivingData: (NSString*)characteristicName;
- (void)stopReceivingData: (NSString*)characteristicName;
- (BOOL)isReceivingData: (NSString*)characteristicName;
- (void)onReceivedData: (NSData*)data from: (NSString*)characteristicName;

- (NSDictionary*)featureWithName: (NSString*)name;
- (void)callFeature: (NSString*)name withValue: (id)value;
- (void)onFeatureResponse: (NSString*)name value:(id)value;
- (id)stateValueOfFeature: (NSString*)name formatted: (BOOL)format;

- (NSArray*)settings;

@end

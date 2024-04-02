//
//  BLEDevice.m
//  BLESensor
//
//  Created by 郝建林 on 16/8/16.
//  Copyright © 2016年 CoolTools. All rights reserved.
//

#import "BLEDevice.h"
#import "BLEManager.h"
#import "CSL.h"

@interface BLEDevice()
{    
    NSMutableArray *servicesOnDiscoveringCharacteristics;

    NSMutableDictionary *characteristicNamesByUUID;
    NSMutableDictionary *characteristicsByName;
}

@end


@implementation BLEDevice

- (id)initWithPeripheral: (CBPeripheral*)peripheral advertisementData: (NSDictionary*)ad classMetadata: (NSDictionary*)classMetadata {
    if(self = [super init]) {
        _peripheral = peripheral;
        _peripheral.delegate = self;
        advertisementData = [NSMutableDictionary dictionaryWithDictionary:ad];
        servicesOnDiscoveringCharacteristics = [NSMutableArray array];
        characteristicNamesByUUID = [NSMutableDictionary dictionary];
        characteristicsByName = [NSMutableDictionary dictionary];
        if(classMetadata) {
            metadata = classMetadata;
            NSArray *servicesArray = classMetadata[@"services"];
            for(NSDictionary *serviceItem in servicesArray) {
                NSArray *characteristicsArray = serviceItem[@"characteristics"];
                for(NSDictionary *characteristicItem in characteristicsArray) {
                    NSString *characteristicUuid = characteristicItem[@"uuid"];
                    NSString *characteristicName = characteristicItem[@"name"];
                    [characteristicNamesByUUID setObject:characteristicName forKey:[CBUUID UUIDWithString:characteristicUuid]];
                }
            }
            [self updateServiceData];
        }
    }
    return self;
}

- (void)updateServiceData {
    NSDictionary *serviceDataConfig = [metadata valueForKeyPath:@"advertisements.serviceData"];
    if(serviceDataConfig) {
        CBUUID *UUID = [CBUUID UUIDWithString:serviceDataConfig[@"uuid"]];
        NSDictionary *serviceDataDict = advertisementData[CBAdvertisementDataServiceDataKey];
        if(serviceDataDict) {
            NSData *serviceDataData = serviceDataDict[UUID];
            if(serviceDataData) {
                int serviceDataLength = 0;
                serviceData = csl_decode(serviceDataData, 0, serviceDataConfig, &serviceDataLength);
            }
        }
    }
}

- (void)updateAdvertisementData: (NSDictionary*)ad {
    for(id key in ad.allKeys)
        [advertisementData setObject:ad[key] forKey:key];
    [self updateServiceData];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.AdvUpdated" object:self];
}

- (NSDictionary*)advertisementData {
    return advertisementData;
}

- (NSString*)deviceKey {
    return [self.peripheral.identifier UUIDString];
}

- (NSString*)deviceInfo {
    return [advertisementData description];
}

- (NSString*)deviceName {
    return advertisementData[CBAdvertisementDataLocalNameKey];
}

- (void)onConnected {
    if(self.peripheral.services == nil) {
        NSMutableArray *serviceUUIDsToDiscover;
        if(metadata != nil) {
            NSArray *services = metadata[@"services"];
            if(services) {
                for(NSDictionary *service in services)
                    [serviceUUIDsToDiscover addObject:[CBUUID UUIDWithString:service[@"uuid"]]];
            }
        }
        [self.peripheral discoverServices:serviceUUIDsToDiscover];
    }
    else {
        NSLog(@"peripheral already has services: %@", self.peripheral.services);
        [self setReady];
    }
}

- (void)setReady {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.Ready" object:self];
}

- (void)onReceiveData: (NSData*)data forProperty: (NSString*)propertyName {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.ReceviedData" object:self userInfo:@{@"data":data, @"property":propertyName}];
}

- (void)onValueChanged: (id)value ofProperty: (NSString*)propertyName {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.ValueChanged" object:self userInfo:@{@"key":propertyName, @"value":value}];
}

- (void)connect {
    CBCentralManager *central = [BLEManager central];
    if(self.peripheral.state != CBPeripheralStateConnected) {
        if(central.state == CBCentralManagerStatePoweredOn)
            [central connectPeripheral:self.peripheral options:nil];
        else
            NSLog(@"central not powered on");
    }
    else {
        NSLog(@"periperal already connected");
        [self onConnected];
    }
}

- (BOOL)isConnected {
    return self.peripheral.state == CBPeripheralStateConnected;
}

- (void)disconnect {
    [[BLEManager central] cancelPeripheralConnection:self.peripheral];
}

- (void)writeData: (NSData*)data forProperty: (NSString*)propertyName {
    CBCharacteristic *characteristic = characteristicsByName[propertyName];
    if(characteristic != nil) {
        if(characteristic.properties & CBCharacteristicPropertyWrite)
            [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        else if(characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)
            [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
        else
            NSLog(@"characteristic cannot be written");
    }
    else
        NSLog(@"charactristic not found of name %@", propertyName);
}

- (void)readData:(NSString *)propertyName {
    CBCharacteristic *characteristic = characteristicsByName[propertyName];
    if(characteristic != nil)
        [self.peripheral readValueForCharacteristic:characteristic];
    else
        NSLog(@"charactristic not found of name %@", propertyName);
}

- (void)startReceiveData: (NSString*)propertyName {
    CBCharacteristic *characteristic = characteristicsByName[propertyName];
    if(characteristic != nil)
        [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
    else
        NSLog(@"charactristic not found of name %@", propertyName);
}

- (void)stopReceiveData: (NSString*)propertyName {
    CBCharacteristic *characteristic = characteristicsByName[propertyName];
    if(characteristic != nil)
        [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
    else
        NSLog(@"charactristic not found of name %@", propertyName);
}

- (BOOL)isReceivingData: (NSString*)propertyName {
    CBCharacteristic *characteristic = characteristicsByName[propertyName];
    if(characteristic != nil)
        return characteristic.isNotifying;
    else
        return NO;
}

#pragma mark - methods for CBPeripheralDelegate

//发现了服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if(error != nil) {
        NSLog(@"CBPeripheral discover services error: %@", error);
        return;
    }
    [servicesOnDiscoveringCharacteristics removeAllObjects];
    [servicesOnDiscoveringCharacteristics addObjectsFromArray:peripheral.services];
    for(CBService *service in [peripheral services])
        //发现特性
        [peripheral discoverCharacteristics:nil forService:service];
}

//发现了特性
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if(error != nil) {
        NSLog(@"CBPeripheral discover characteristics of service %@ error: %@", service, error);
        return;
    }
    [servicesOnDiscoveringCharacteristics removeObject:service];
    for(CBCharacteristic *characteristic in [service characteristics])
    {
        CBUUID *characteristicUUID = characteristic.UUID;
        NSString *characteristicName = characteristicNamesByUUID[characteristicUUID];
        if(characteristicName != nil)
            [characteristicsByName setObject:characteristic forKey:characteristicName];
    }
    if(servicesOnDiscoveringCharacteristics.count == 0)
        [self setReady];
}

//接收读特性的返回和通知特性
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error != nil) {
        NSLog(@"CBPeripheral update value of characteristic %@ error: %@", characteristic, error);
        return;
    }
    NSString *propertyName = characteristicNamesByUUID[characteristic.UUID];
    if(propertyName != nil) {
        [self onReceiveData:characteristic.value forProperty:propertyName];
        NSLog(@"updated value of %@: %@", propertyName, characteristic.value);
    }
    else
        NSLog(@"updated value of %@: %@", characteristic.UUID, characteristic.value);
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error == nil) {
        NSLog(@"Value write succeed!");
    }else{
        NSLog(@"Value write failed: %@", error);
    }
}
@end

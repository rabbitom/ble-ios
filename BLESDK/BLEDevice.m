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
#import "Events.h"

@interface BLEDevice()
{    
    NSMutableArray *servicesOnDiscoveringCharacteristics;

    NSMutableDictionary *characteristicNamesByUUID;
    NSMutableDictionary *characteristicsByName;
}

@end


@implementation BLEDevice

- (id)initWithPeripheral: (CBPeripheral*)peripheral advertisementData: (NSDictionary*)ad classMetadata: (NSDictionary*)classMetadata {
    if(self = [super initWithMetadata:classMetadata]) {
        _peripheral = peripheral;
        _peripheral.delegate = self;
        advertisementData = [NSMutableDictionary dictionaryWithDictionary:ad];
        servicesOnDiscoveringCharacteristics = [NSMutableArray array];
        characteristicNamesByUUID = [NSMutableDictionary dictionary];
        characteristicsByName = [NSMutableDictionary dictionary];
        if(classMetadata) {
            if(classMetadata[@"services"])
                [self updateServices: classMetadata[@"services"]];
        }
        [self updateServiceData];
    }
    return self;
}

- (NSString*)deviceKey {
    return [self.peripheral.identifier UUIDString];
}

- (NSDictionary*)advertisementData {
    return advertisementData;
}

- (NSString*)deviceName {
    NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
    return localName ? localName : self.peripheral.name;
}

- (void)updateServices: (NSArray*)servicesArray {
    for(NSDictionary *serviceItem in servicesArray) {
        NSArray *characteristicsArray = serviceItem[@"characteristics"];
        for(NSDictionary *characteristicItem in characteristicsArray) {
            NSString *characteristicUuid = characteristicItem[@"uuid"];
            NSString *characteristicName = characteristicItem[@"name"];
            [characteristicNamesByUUID setObject:characteristicName forKey:[CBUUID UUIDWithString:characteristicUuid]];
        }
    }
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
    if(ad[CBAdvertisementDataLocalNameKey])
        state[@"localName"] = ad[CBAdvertisementDataLocalNameKey];
    [self updateServiceData];
    [[NSNotificationCenter defaultCenter] postNotificationName:AdvUpdated object:self];
}

#pragma mark - connect

- (BOOL)connect {
    CBCentralManager *central = [BLEManager central];
    if(self.peripheral.state != CBPeripheralStateConnected) {
        if(central.state == CBManagerStatePoweredOn) {
            [central connectPeripheral:self.peripheral options:nil];
            return YES;
        }
        else
            NSLog(@"[BLE]connect failed: central not powered on");
    }
    else {
        NSLog(@"[BLE]periperal already connected");
        [self onConnected];
    }
    return NO;
}

- (BOOL)isConnected {
    return self.peripheral.state == CBPeripheralStateConnected;
}

- (void)disconnect {
    [[BLEManager central] cancelPeripheralConnection:self.peripheral];
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
        NSLog(@"[BLE]peripheral already has services: %@", self.peripheral.services);
        [self beforeReady];
    }
}

#pragma mark - data

- (void)writeData: (NSData*)data to: (NSString*)characteristicName {
    if(!self.isConnected)
        @throw [NSException exceptionWithName:@"write data failed" reason:@"device is disconnected" userInfo:nil];
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil) {
        NSLog(@"[BLE][Data]->%@: %@", characteristicName, data);
        if(characteristic.properties & CBCharacteristicPropertyWrite)
            [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        else if(characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)
            [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
        else
            @throw [NSException exceptionWithName:@"write data faield" reason:@"characteristic does not support write" userInfo:@{@"name":characteristicName,@"uuid":characteristic.UUID}];
    }
    else
        @throw [NSException exceptionWithName:@"write data failed" reason:@"charactristic not found" userInfo:@{@"name":characteristicName}];
}

- (void)readData:(NSString *)characteristicName {
    if(!self.isConnected)
        @throw [NSException exceptionWithName:@"read data failed" reason:@"device is disconnected" userInfo:nil];
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        [self.peripheral readValueForCharacteristic:characteristic];
    else
        NSLog(@"[BLE]charactristic not found of name %@", characteristicName);
}

- (void)startNotification: (NSString*)characteristicName {
    if(!self.isConnected)
        @throw [NSException exceptionWithName:@"start receiving data failed" reason:@"device is disconnected" userInfo:nil];
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
    else
        NSLog(@"[BLE]charactristic not found of name %@", characteristicName);
}

- (void)stopNotification: (NSString*)characteristicName {
    if(!self.isConnected)
        @throw [NSException exceptionWithName:@"start receiving data failed" reason:@"device is disconnected" userInfo:nil];
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
    else
        NSLog(@"[BLE]charactristic not found of name %@", characteristicName);
}

- (BOOL)isNofitying: (NSString*)characteristicName {
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        return characteristic.isNotifying;
    else
        return NO;
}

- (void)onReceivedData: (NSData*)data from: (NSString*)characteristicName {
    if([characteristicName isEqual:@"recv"])
        [super onReceivedData:data];
    else
        [[NSNotificationCenter defaultCenter] postNotificationName:ReceviedData object:self userInfo:@{@"data":data, @"property":characteristicName}];
}

#pragma mark - CBPeripheralDelegate

//发现了服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if(error == nil) {
        [servicesOnDiscoveringCharacteristics removeAllObjects];
        [servicesOnDiscoveringCharacteristics addObjectsFromArray:peripheral.services];
        for(CBService *service in [peripheral services])
            //发现特性
            [peripheral discoverCharacteristics:nil forService:service];
    }
    else
        NSLog(@"[BLE]discover services of peripheral %@ failed: %@", peripheral.identifier, error);
}

//发现了特性
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if(error == nil) {
        [servicesOnDiscoveringCharacteristics removeObject:service];
        for(CBCharacteristic *characteristic in [service characteristics])
        {
            CBUUID *characteristicUUID = characteristic.UUID;
            NSString *characteristicName = characteristicNamesByUUID[characteristicUUID];
            if(characteristicName != nil)
                [characteristicsByName setObject:characteristic forKey:characteristicName];
        }
        if(servicesOnDiscoveringCharacteristics.count == 0)
            [self beforeReady];
    }
    else
        NSLog(@"[BLE]discover characteristics of service %@ failed: %@", service.UUID, error);
}

//接收读特性的返回和通知特性
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error == nil) {
        NSString *characteristicName = characteristicNamesByUUID[characteristic.UUID];
        NSLog(@"[BLE][Data]<-%@: %@", characteristicName ? characteristicName : characteristic.UUID, characteristic.value);
        if(characteristicName)
            [self onReceivedData:characteristic.value from:characteristicName];
    }
    else
        NSLog(@"[BLE]update value of characteristic %@ failed: %@", characteristic.UUID, error);
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error != nil)
        NSLog(@"[BLE]write value of characteristic %@ failed: %@", characteristic.UUID, error);
}

#pragma mark - CSLDevice methods

- (void)beforeReady {
    [self startNotification: @"recv"];
    [super beforeReady];
}

- (void)sendData:(NSData *)data {
    [self writeData:data to:@"send"];
}

@end

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
    
    NSMutableDictionary *featuresByName;
    NSMutableDictionary *featuresById;
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
        featuresByName = [NSMutableDictionary dictionary];
        featuresById = [NSMutableDictionary dictionary];
        state = [NSMutableDictionary dictionary];
        if(classMetadata) {
            metadata = classMetadata;
            if(metadata[@"services"])
                [self updateServices: metadata[@"services"]];
            if(metadata[@"features"])
                [self updateFeatures: metadata[@"features"]];
            [self updateServiceData];
        }
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
    return advertisementData[CBAdvertisementDataLocalNameKey];
}

- (NSMutableDictionary*)state {
    return state;
}

- (NSArray*)settings {
    return metadata[@"settings"];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.AdvUpdated" object:self];
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
            NSLog(@"central not powered on");
    }
    else {
        NSLog(@"periperal already connected");
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
        NSLog(@"peripheral already has services: %@", self.peripheral.services);
        [self onReady];
    }
}

- (void)onReady {
    [self startReceivingData:@"recv"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.Ready" object:self];
}

#pragma mark - data

- (void)writeData: (NSData*)data to: (NSString*)characteristicName {
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
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        [self.peripheral readValueForCharacteristic:characteristic];
    else
        NSLog(@"charactristic not found of name %@", characteristicName);
}

- (void)startReceivingData: (NSString*)characteristicName {
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
    else
        NSLog(@"charactristic not found of name %@", characteristicName);
}

- (void)stopReceivingData: (NSString*)characteristicName {
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
    else
        NSLog(@"charactristic not found of name %@", characteristicName);
}

- (BOOL)isReceivingData: (NSString*)characteristicName {
    CBCharacteristic *characteristic = characteristicsByName[characteristicName];
    if(characteristic != nil)
        return characteristic.isNotifying;
    else
        return NO;
}

- (void)onReceivedData: (NSData*)data from: (NSString*)characteristicName {
    if([characteristicName isEqual:@"recv"] && metadata[@"packet"]) {
        int decodeLength = 0;
        NSDictionary *packet;
        @try {
            packet = csl_decode(data, 0, metadata[@"packet"], &decodeLength);
        }
        @catch(NSException *exception) {
            NSLog(@"[BLE]decoding packet failed: %@", exception);
            return;
        }
        NSNumber *featureId = packet[@"featureId"];
        id featurePayload = packet[@"featurePayload"];
        if(featurePayload) {
            NSDictionary *feature = featuresById[featureId];
            if(feature != nil) {
                id value;
                NSDictionary *payloadConfig = (feature[@"response"] != nil) ? feature[@"response"] : feature[@"payload"];
                if(payloadConfig) {
                    @try {
                        value = csl_decode(featurePayload, 0, payloadConfig, &decodeLength);
                    }
                    @catch(NSException *exception) {
                        NSLog(@"[BLE]decoding feature payload failed: %@", exception);
                        return;
                    }
                    NSString *stateKeyPath = feature[@"stateKeyPath"];
                    if(stateKeyPath) {
                        if([stateKeyPath isEqualToString:@"..."]) {
                            if([value isKindOfClass:[NSDictionary class]]) {
                                [(NSDictionary*)value enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                                    [state setValue:obj forKeyPath:key];
                                }];
                            }
                        }
                        else if([stateKeyPath hasSuffix:@"[]"]) {
                            stateKeyPath = [stateKeyPath substringWithRange:NSMakeRange(0, stateKeyPath.length - 2)];
                            NSMutableArray *array = [state valueForKeyPath:stateKeyPath];
                            if(array == nil) {
                                array = [NSMutableArray array];
                                [state setValue:array forKeyPath:stateKeyPath];
                            }
                            [array addObject:value];
                        }
                        else
                            [state setValue:value forKeyPath:feature[@"stateKeyPath"]];
                    }
                }
                [self onFeatureResponse:feature[@"name"] value:value];
            }
            else
                NSLog(@"feature not found: %#X", [featureId intValue]);
        }
    }
    else
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.ReceviedData" object:self userInfo:@{@"data":data, @"property":characteristicName}];
}

#pragma mark - features

- (NSDictionary*)featureWithName: (NSString*)name {
    return featuresByName[name];
}

- (void)updateFeatures: (NSArray*)featuresArray {
    [featuresArray enumerateObjectsUsingBlock:^(NSDictionary *feature, NSUInteger idx, BOOL * _Nonnull stop) {
        [featuresByName setObject:feature forKey:feature[@"name"]];
        id featureId = feature[@"id"];
        if([featureId isKindOfClass:[NSString class]]) {
            NSData *data = csl_parse_hex_str(featureId);
            featureId = [NSNumber numberWithUnsignedChar:((Byte*)[data bytes])[0]];
        }
        [featuresById setObject:feature forKey:featureId];
    }];
}

- (id)stateValueOfFeature: (NSString*)featureName formatted: (BOOL)format {
    id value;
    NSDictionary *feature = featuresByName[featureName];
    if(feature) {
        if(feature[@"stateKeyPath"]) {
            value = [state valueForKeyPath:feature[@"stateKeyPath"]];
            if(value != nil && format) {
                NSDictionary *config = feature;
                for(NSString *payloadKey in @[@"request", @"response", @"payload"]) {
                    config = feature[payloadKey];
                    if(config)
                        break;
                }
                value = csl_format_value(value, config);
            }
        }
    }
    return value;
}

- (BOOL)callFeature: (NSString*)name withValue: (id)value {
    NSDictionary *feature = featuresByName[name];
    if(feature == nil)
        @throw [NSException exceptionWithName:@"Call feature failed" reason:@"feature not found" userInfo:@{@"name":name}];
    NSDictionary *packetConfig = metadata[@"packet"];
    NSMutableDictionary *packetValue = [NSMutableDictionary dictionaryWithDictionary:@{@"featureId": feature[@"id"]}];
    if(feature[@"request"]) {
        if(value) {
            NSData *payload = csl_encode(value, feature[@"request"]);
            [packetValue setObject:payload forKey:@"featurePayload"];
        }
        else
            @throw [NSException exceptionWithName:@"Call feature failed" reason:@"value not set" userInfo:@{@"name":name}];
    }
    NSData *packet = csl_encode(packetValue, packetConfig);
    [self writeData:packet to:@"send"];
    return NO;
}

- (void)onFeatureResponse: (NSString*)name value:(id)value  {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"name":name}];
    if(value)
        userInfo[@"value"] = value;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.FeatureResponse" object:self userInfo:userInfo];
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
        NSLog(@"CBPeripheral discover services error: %@", error);
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
            [self onReady];
    }
    else
        NSLog(@"CBPeripheral discover characteristics of service %@ error: %@", service, error);
}

//接收读特性的返回和通知特性
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error == nil) {
        NSString *characteristicName = characteristicNamesByUUID[characteristic.UUID];
        if(characteristicName)
            [self onReceivedData:characteristic.value from:characteristicName];
        NSLog(@"[BLE][Data]<-%@: %@", characteristicName ? characteristicName : characteristic.UUID, characteristic.value);
    }
    else
        NSLog(@"[BLE]update value failed: %@", error);
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error != nil)
        NSLog(@"[BLE]write value failed: %@", error);
}
@end

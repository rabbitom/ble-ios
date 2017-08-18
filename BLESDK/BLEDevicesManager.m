//
//  BLEDevicesManager.m
//  BLESensor
//
//  Created by 郝建林 on 16/8/16.
//  Copyright © 2016年 CoolTools. All rights reserved.
//

#import "BLEDevicesManager.h"
#import "BLEDevice.h"
#import "BLEUtility.h"
#import "CoolUtility.h"

@implementation BLEDevicesManager
{
    CBCentralManager *centralManager;
    NSMutableArray *deviceClasses;//class{mainService/advertisementName}
    NSMutableDictionary *devices;//NSUUID(peripheral.identifier):BLEDevice
    NSMutableArray *deviceBuffer;//NSUUID
}

@synthesize filterDeviceOfUnknownClass;

static id instance;

+ (instancetype)sharedInstance {
    if(instance == nil)
        instance = [[self.class alloc] init];
    return instance;
}

+ (CBCentralManager*)central {
    return [[self.class sharedInstance] centralManager];
}

- (CBCentralManager*)centralManager {
    return centralManager;
}

- (id)init {
    if(self = [super init]) {
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey: @YES}];
        deviceClasses = [NSMutableArray array];
        devices = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addSearchFilter: (NSString*)filePath {
    @try {
        if(filePath == nil)
            @throw [NSException exceptionWithName:@"FileNotFound" reason:@"Device definition file not found" userInfo:@{@"path":filePath}];
        NSData *filterData = [NSData dataWithContentsOfFile:filePath];
        NSError *error = nil;
        id filter = [NSJSONSerialization JSONObjectWithData:filterData options:NSJSONReadingAllowFragments error:&error];
        if(error)
            @throw [NSException exceptionWithName:@"JSON Error" reason:@"Cannot parse JSON" userInfo:@{@"error": error}];
        if(![filter isKindOfClass:[NSDictionary class]])
            @throw [NSException exceptionWithName:@"JSON Error" reason:@"JSON object is not NSDictionary" userInfo:nil];
        [self addDeviceClassByMetadata: filter];
    }
    @catch (NSException *exception) {
        NSLog(@"parse bledevices failed: %@", exception);
    }
}

- (void)searchDevices {
    if(deviceBuffer == nil)
        deviceBuffer = [NSMutableArray array];
    else
        [deviceBuffer removeAllObjects];
    if(self.filterSearchByMainServices) {
        NSMutableArray *serviceUUIDs = [NSMutableArray array];
        for(NSDictionary *deviceClassMetadata in deviceClasses) {
            CBUUID *classMainServiceUUID = deviceClassMetadata[@"mainServiceUUID"];
            if(classMainServiceUUID != nil)
               [serviceUUIDs addObject:classMainServiceUUID];
        }
        [centralManager scanForPeripheralsWithServices:serviceUUIDs options:nil];
    }
    else
        [centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void)stopSearching {
    [centralManager stopScan];
}

- (void)addDeviceClassByMetadata: (NSDictionary*)metadata {
    NSString *className = metadata[@"class"];
    if(className != nil) {
        Class deviceClass = NSClassFromString(className);
        if(deviceClasses != nil) {
            NSMutableDictionary *deviceClassMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
            deviceClassMetadata[@"class"] = deviceClass;
            NSDictionary *advertisement = deviceClassMetadata[@"advertisement"];
            if(advertisement != nil) {
                NSString *mainService = advertisement[@"service"];
                if(mainService != nil)
                    deviceClassMetadata[@"mainServiceUUID"] = [CBUUID UUIDWithString:mainService];
                [deviceClasses addObject:deviceClassMetadata];
            }
        }
    }
}

- (id)findDevice: (NSUUID*)deviceId {
    return devices[deviceId];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"CBCentralManager State: %@", [BLEUtility centralState:central.state]);
}

- (BOOL)checkForAdvertisementName: (NSString*)advertisementName withClass: (NSDictionary*)deviceClassMetadata {
    NSDictionary *advertisement = deviceClassMetadata[@"advertisement"];
    if(advertisement != nil) {
        NSString *classAdvertisementNamePattern = advertisement[@"nameFilterPattern"];
        if(classAdvertisementNamePattern != nil) {
            if(advertisementName != nil) {
                NSPredicate *namePre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", classAdvertisementNamePattern];
                return [namePre evaluateWithObject:advertisementName];
            }
            else
                return NO;
        }
    }
    return YES;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if([deviceBuffer containsObject:peripheral.identifier]) {
        NSLog(@"found peripheral again: %@ rssi: %@\nadvertisement: %@ ", peripheral, RSSI, advertisementData);
        id device = devices[peripheral.identifier];
        if(device != nil) {
            [(BLEDevice*)device updateAdvertisementData: advertisementData];
            ((BLEDevice*)device).rssi = [RSSI intValue];
        }
        return;
    }
    NSLog(@"found peripheral: %@ rssi: %@\nadvertisement: %@ ", peripheral, RSSI, advertisementData);
    [deviceBuffer addObject:peripheral.identifier];
    Class deviceClass = nil;
    NSDictionary *deviceClassMetadata = nil;
    NSString *advertisementName = advertisementData[CBAdvertisementDataLocalNameKey];
    NSArray *serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    for(NSDictionary *deviceClassItem in deviceClasses) {
        CBUUID *classMainServiceUUID = deviceClassItem[@"mainServiceUUID"];
        if((classMainServiceUUID != nil) && (serviceUUIDs != nil) && [serviceUUIDs containsObject:classMainServiceUUID]) {
            if([self checkForAdvertisementName:advertisementName withClass:deviceClassItem]) {
                deviceClass = deviceClassItem[@"class"];
                deviceClassMetadata = deviceClassItem;
                break;
            }
        }
    }
    id device = devices[peripheral.identifier];
    if(device == nil) {
        if(deviceClass == nil) {
            if(self.filterDeviceOfUnknownClass)
                return;
            else
                deviceClass = [BLEDevice class];
        }
        device = [[deviceClass alloc] initWithPeripheral: peripheral advertisementData:advertisementData classMetadata:deviceClassMetadata];
        NSLog(@"device created for peripheral: %@ of class: %@", peripheral, NSStringFromClass(deviceClass));
        [devices setObject:device forKey:peripheral.identifier];
    }
    else {
        CBPeripheral *originalPeripheral = [(BLEDevice*)device peripheral];
        if(originalPeripheral != peripheral)
            NSLog(@"device already created with peripheral: %@, new found peripheral: %@", originalPeripheral, peripheral);
    }
    ((BLEDevice*)device).rssi = [RSSI intValue];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.FoundDevice" object:device];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"connected peripheral: %@", peripheral);
    BLEDevice *device = [self findDevice:peripheral.identifier];
    if(device != nil) {
        [device onConnected];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.Connected" object:device];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"disconnected peripheral: %@, error: %@", peripheral, error);
    BLEDevice *device = [self findDevice:peripheral.identifier];
    if(device != nil)
        //[device onDisconnected];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.Disconnected" object:device userInfo:@{@"error": (error != nil) ? error : [NSNull null]}];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"failed to connect peripheral: %@, error: %@", peripheral, error);
    BLEDevice *device = [self findDevice:peripheral.identifier];
    if(device != nil)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDevice.FailedToConnect" object:device userInfo:@{@"error": (error != nil) ? error : [NSNull null]}];
}

@end

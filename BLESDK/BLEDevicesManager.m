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

- (void)loadDevices: (NSString*)devicesPath {
    @try {
        if(devicesPath == nil)
            @throw [NSException exceptionWithName:@"FileNotFound" reason:@"bledevices.json file not found" userInfo:nil];
        NSData *devicesData = [NSData dataWithContentsOfFile:devicesPath];
        NSError *error = nil;
        id bleDevices = [NSJSONSerialization JSONObjectWithData:devicesData options:NSJSONReadingAllowFragments error:&error];
        if(error)
            @throw [NSException exceptionWithName:@"JSON Error" reason:@"Cannot parse JSON" userInfo:@{@"error": error}];
        if(![bleDevices isKindOfClass:[NSArray class]])
            @throw [NSException exceptionWithName:@"JSON Error" reason:@"JSON object is not NSArray" userInfo:nil];
        for(NSDictionary *deviceMetadata in (NSArray*)bleDevices)
            [self addDeviceClassByMetadata: deviceMetadata];
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
    NSString *className = metadata[@"className"];
    if(className != nil) {
        Class deviceClass = NSClassFromString(className);
        if(deviceClasses != nil) {
            NSMutableDictionary *deviceClassMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
            deviceClassMetadata[@"class"] = deviceClass;
            NSString *mainService = deviceClassMetadata[@"mainService"];
            if(mainService != nil)
                deviceClassMetadata[@"mainServiceUUID"] = [CBUUID UUIDWithString:mainService];
            [deviceClasses addObject:deviceClassMetadata];
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
    NSString *advertisementName = advertisementData[CBAdvertisementDataLocalNameKey];
    NSArray *serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    for(NSDictionary *deviceClassMetadata in deviceClasses) {
        NSString *classAdvertisementName = deviceClassMetadata[@"advertisementName"];
        if((classAdvertisementName != nil) && (advertisementName != nil) && [advertisementName containsString:classAdvertisementName])  {
            deviceClass = deviceClassMetadata[@"class"];
            break;
        }
        CBUUID *classMainServiceUUID = deviceClassMetadata[@"mainServiceUUID"];
        if((classMainServiceUUID != nil) && (serviceUUIDs != nil) && [serviceUUIDs containsObject:classMainServiceUUID]) {
            deviceClass = deviceClassMetadata[@"class"];
            break;
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
        device = [[deviceClass alloc] initWithPeripheral: peripheral advertisementData:advertisementData];
        ((BLEDevice*)device).rssi = [RSSI intValue];
        NSLog(@"device created for peripheral: %@ of class: %@", peripheral, NSStringFromClass(deviceClass));
        [devices setObject:device forKey:peripheral.identifier];
    }
    else {
        CBPeripheral *originalPeripheral = [(BLEDevice*)device peripheral];
        if(originalPeripheral != peripheral)
            NSLog(@"device already created with peripheral: %@, new found peripheral: %@", originalPeripheral, peripheral);
    }
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

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
        _isScanning = NO;
    }
    return self;
}

- (void)addDeviceClassFromFile: (NSString*)filePath {
    @try {
        if(filePath == nil)
            @throw [NSException exceptionWithName:@"FileNotFound" reason:@"Device definition file not found" userInfo:@{@"path":filePath}];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        NSError *error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        if(error)
            @throw [NSException exceptionWithName:@"JSON Error" reason:@"Cannot parse JSON" userInfo:@{@"error": error}];
        if(![json isKindOfClass:[NSDictionary class]])
            @throw [NSException exceptionWithName:@"JSON Error" reason:@"JSON object is not NSDictionary" userInfo:nil];
        [self addDeviceClass: json];
    }
    @catch (NSException *exception) {
        NSLog(@"parse bledevices failed: %@", exception);
    }
}

- (void)startScan {
    if(deviceBuffer == nil)
        deviceBuffer = [NSMutableArray array];
    else
        [deviceBuffer removeAllObjects];
    [centralManager scanForPeripheralsWithServices:nil options:nil];
    _isScanning = YES;
}

- (void)stopScan {
    [centralManager stopScan];
    _isScanning = NO;
}

- (void)addDeviceClass: (NSDictionary*)metadata {
    NSString *className = metadata[@"class"];
    if(className != nil)
        [deviceClasses addObject:metadata];
    else
        @throw [NSException exceptionWithName:@"Metadata Error" reason:@"class name not defined" userInfo:metadata];
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
    NSDictionary *deviceClassMetadata = nil;
    for(NSDictionary *deviceClassItem in deviceClasses) {
        NSDictionary *scanFilters = deviceClassItem[@"scanFilters"];
        if(scanFilters != nil) {
// filter by name
            NSDictionary *scanFilterByName = scanFilters[@"name"];
            if(scanFilterByName != nil) {
                NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
                if(localName != nil) {
                    NSString *scanFilterByNameEql = scanFilterByName[@"eql"];
                    NSString *scanFilterByNameMatch = scanFilterByName[@"match"];
                    if(scanFilterByNameEql != nil) {
                        if([scanFilterByNameEql isEqualToString:localName]) {
                            deviceClassMetadata = deviceClassItem;
                            break;
                        }
                    }
                    else if(scanFilterByNameMatch != nil) {
                        NSPredicate *namePre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", scanFilterByNameMatch];
                        if([namePre evaluateWithObject:localName]) {
                            deviceClassMetadata = deviceClassItem;
                            break;
                        }
                    }
                }
            }
// filter by serviceUUIDs
            NSDictionary *scanFilterByServiceUUIDs = scanFilters[@"serviceUUIDs"];
            if(scanFilterByServiceUUIDs != nil) {
                NSArray *serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey];
                if(serviceUUIDs != nil) {
                    NSString *scanFilterByServiceUUIDsContain = scanFilterByServiceUUIDs[@"contain"];
                    if(scanFilterByServiceUUIDsContain != nil) {
                        if([serviceUUIDs containsObject:[CBUUID UUIDWithString:scanFilterByServiceUUIDsContain]]) {
                            deviceClassMetadata = deviceClassItem;
                            break;
                        }
                    }
                }
            }
// filter by serviceData
            NSDictionary *scanFilterByServiceData = scanFilters[@"serviceData"];
            if(scanFilterByServiceData != nil) {
                NSDictionary *serviceData = advertisementData[CBAdvertisementDataServiceDataKey];
                if(serviceData != nil) {
                    NSString *scanFilterByServiceDataUUID = scanFilterByServiceData[@"uuid"];
                    if(scanFilterByServiceDataUUID != nil) {
                        CBUUID *UUID = [CBUUID UUIDWithString:scanFilterByServiceDataUUID];
                        if(serviceData[UUID] != nil) {
                            deviceClassMetadata = deviceClassItem;
                            break;
                        }
                    }
                }
            }
        }
    }
    if(deviceClassMetadata != nil)
        deviceClass = NSClassFromString(deviceClassMetadata[@"class"]);
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

//
//  CSLDevice.m
//  BLESDK
//
//  Created by Tom on 2024/4/17.
//  Copyright © 2024 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSLDevice.h"
#import "CSL.h"
#import "Events.h"

@implementation CSLDevice
{
    NSMutableDictionary *featuresByName;
    NSMutableDictionary *featuresById;
    
    BOOL loadingFeaturesBeforeReady;
    int loadingFeatureIndex;
    
    BOOL isBusy;
    BOOL isPolling;
    BOOL isReady;
    NSUInteger pollingIndex;
}

- (id)initWithMetadata:(NSDictionary *)_metadata {
    if(self = [super init]) {
        featuresByName = [NSMutableDictionary dictionary];
        featuresById = [NSMutableDictionary dictionary];
        state = [NSMutableDictionary dictionary];
        if(_metadata) {
            metadata = _metadata;
            if(metadata[@"features"])
                [self updateFeatures: metadata[@"features"]];
        }
    }
    return self;
}

- (NSMutableDictionary*)state {
    return state;
}

- (BOOL)isBusy {
    return isBusy;
}

- (void)beforeReady {
    if(metadata[@"featuresBeforeReady"]) {
        isReady = NO;
        loadingFeatureIndex = 0;
        [self loadFeatureBeforeReady];
    }
    else
        [self onReady];
}

- (void)loadFeatureBeforeReady {
    NSArray *featuresBeforeReady = metadata[@"featuresBeforeReady"];
    loadingFeaturesBeforeReady = loadingFeatureIndex < featuresBeforeReady.count;
    if(loadingFeaturesBeforeReady)
        [self callFeature:featuresBeforeReady[loadingFeatureIndex++] withValue:nil];
    else
        [self onReady];
}

- (void)onReady {
    isReady = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceReady object:self];
}

- (BOOL)isReady {
    return isReady;
}

- (BOOL)isPolling {
    return isPolling;
}

- (void)startPolling {
    isPolling = YES;
    pollingIndex = 0;
    NSLog(@"[CSL]polling started");
    [self poll];
}

- (void)stopPolling {
    isPolling = NO;
    NSLog(@"[CSL]polling stopped");
}

- (void)poll {
    NSArray *pollingFeatures = metadata[@"polling"][@"features"];
    NSString *pollingFeature = pollingFeatures[pollingIndex];
    NSLog(@"[CSL]polling feature: %@", pollingFeature);
    @try {
        [self callFeature:pollingFeature withValue:nil];
    }
    @catch(NSException *exception) {
        NSLog(@"[CSL]poll feature failed: %@", exception);
        [self stopPolling];
    }
    pollingIndex = (pollingIndex + 1) % pollingFeatures.count;
}

- (void)updateStateValue: (id)value keyPath: (NSString*)keyPath {
    if([keyPath isEqualToString:@"..."]) {
        if([value isKindOfClass:[NSDictionary class]]) {
            [(NSDictionary*)value enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [state setValue:obj forKeyPath:key];
            }];
        }
    }
    else if([keyPath hasSuffix:@"[]"]) {
        keyPath = [keyPath substringWithRange:NSMakeRange(0, keyPath.length - 2)];
        NSMutableArray *array = [state valueForKeyPath:keyPath];
        if(array == nil) {
            array = [NSMutableArray array];
            [state setValue:array forKeyPath:keyPath];
        }
        [array addObject:value];
    }
    else
        [state setValue:value forKeyPath:keyPath];
}

- (NSDictionary*)onReceivedPacket: (NSDictionary*)packet {
    NSNumber *featureId = packet[@"featureId"];
    NSDictionary *feature = featuresById[featureId];
    if(feature != nil) {
        id value;
        id featurePayload = packet[@"featurePayload"];
        if(featurePayload != nil) {
            NSDictionary *payloadConfig = (feature[@"response"] != nil) ? feature[@"response"] : feature[@"payload"];
            if(payloadConfig) {
                int decodeLength = 0;
                @try {
                    value = csl_decode(featurePayload, 0, payloadConfig, &decodeLength);
                }
                @catch(NSException *exception) {
                    NSLog(@"[CSL]decoding feature payload failed: %@", exception);
                }
                if(value) {
                    NSString *stateKeyPath = payloadConfig[@"stateKeyPath"];
                    if(stateKeyPath)
                        [self updateStateValue:value keyPath:stateKeyPath];
                    return @{@"name":feature[@"name"],@"value":value};
                }
            }
        }
        return @{@"name":feature[@"name"]};
    }
    else {
        NSLog(@"[CSL]feature not found: %#X", [featureId intValue]);
        return nil;
    }
}

- (void)onReceivedData: (NSData*)data {
    if(metadata[@"packet"]) {
        isBusy = NO;
        int decodeLength = 0;
        int totalLength = 0;
        NSDictionary *packetFeature;
        while(totalLength < data.length) {
            NSDictionary *packet;
            @try {
                packet = csl_decode(data, totalLength, metadata[@"packet"], &decodeLength);
            }
            @catch(NSException *exception) {
                NSLog(@"[CSL]decoding packet failed: %@", exception);
                break;
            }
            totalLength += decodeLength;
            if(packet)
                packetFeature = [self onReceivedPacket: packet];
        }
        if(loadingFeaturesBeforeReady)
            [self loadFeatureBeforeReady];
        else if(packetFeature)
            [self onFeatureResponse:packetFeature[@"name"] value:packetFeature[@"value"]];
        if(isPolling)
            [self poll];
    }
}

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

- (id)stateValueOf: (NSDictionary*)config formatted: (BOOL)format {
    id value;
    NSString *stateKeyPath = config[@"stateKeyPath"];
    if(stateKeyPath) {
        if([stateKeyPath isEqualToString:@"..."]) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            for(NSDictionary *attr in config[@"attributes"]) {
                NSString *attrName = attr[@"name"];
                id attrValue = state[attrName];
                [dict setValue:attrValue forKeyPath:attrName];
            }
            value = dict;
        }
        else {
            if([stateKeyPath hasSuffix:@"[]"])
                stateKeyPath = [stateKeyPath substringWithRange: NSMakeRange(0, stateKeyPath.length - 2)];
            value = [state valueForKeyPath:stateKeyPath];
        }
        if(value != nil && format)
            value = csl_format_value(value, config);
    }
    return value;
}

- (BOOL)callFeature: (NSString*)name withValue: (id)value {
    NSDictionary *feature = featuresByName[name];
    if(feature == nil)
        @throw [NSException exceptionWithName:@"Call feature failed" reason:@"feature not found" userInfo:@{@"name":name}];
    NSDictionary *packetConfig = metadata[@"packet"];
    NSMutableDictionary *packetValue = [NSMutableDictionary dictionaryWithDictionary:@{@"featureId": feature[@"id"]}];
    NSDictionary *featureRequest = feature[@"request"];
    if(featureRequest) {
        if(value) {
            NSData *payload = csl_encode(value, featureRequest);
            [packetValue setObject:payload forKey:@"featurePayload"];
            if(featureRequest[@"stateKeyPath"])
                [self updateStateValue:value keyPath:featureRequest[@"stateKeyPath"]];
        }
        else
            @throw [NSException exceptionWithName:@"Call feature failed" reason:@"value not set" userInfo:@{@"name":name}];
    }
    NSData *packet = csl_encode(packetValue, packetConfig);
    [self sendData: packet];
    isBusy = YES;
    return NO;
}

- (void)onFeatureResponse: (NSString*)name value:(id)value  {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"name":name}];
    if(value)
        userInfo[@"value"] = value;
    [[NSNotificationCenter defaultCenter] postNotificationName:FeatureResponse object:self userInfo:userInfo];
}

#pragma mark - virtual methods

- (void)sendData:(NSData *)data {
    //virtual
}

@end

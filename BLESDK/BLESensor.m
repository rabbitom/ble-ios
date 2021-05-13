//
//  BLESensor.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLESensor.h"
#import "BLESensorFeature.h"

@interface BLESensor()
{
    NSMutableDictionary *features;
}
@end

@implementation BLESensor

- (id)initWithPeripheral: (CBPeripheral*)peripheral advertisementData: (NSDictionary*)ad classMetadata: (NSDictionary*)classMetadata {
    if(self = [super initWithPeripheral:peripheral advertisementData:ad classMetadata:classMetadata]) {
        NSArray *servicesArray = classMetadata[@"services"];
        if(servicesArray) {
            for(NSDictionary *serviceItem in servicesArray) {
                NSArray *characteristicsArray = serviceItem[@"characteristics"];
                if(characteristicsArray) {
                    for(NSDictionary *characteristicItem in characteristicsArray) {
                        NSString *characteristicName = characteristicItem[@"name"];
                        if([characteristicItem[@"function"] isEqual: @"feature"]) {
                            if(features == nil)
                                features = [NSMutableDictionary dictionary];
                            features[characteristicName] = [[BLESensorFeature alloc] initWithConfig: characteristicItem];
                        }
                    }
                }
            }
        }
    }
    return self;
}

- (NSDictionary*)features {
    return features;
}

- (void)onReceiveData: (NSData*)data forProperty: (NSString*)propertyName {
    BLESensorFeature *feature = features[propertyName];
    if(feature != nil) {
        if([feature parseData:data])
            [self onValueChanged:feature ofProperty:propertyName];
    }
}

@end

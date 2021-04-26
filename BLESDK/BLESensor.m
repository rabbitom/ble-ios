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

- (NSDictionary*)features {
    return features;
}

- (void)setReady {
    features = [NSMutableDictionary dictionary];
    [super setReady];
}

- (void)onReceiveData: (NSData*)data forProperty: (NSString*)propertyName {
    BLESensorFeature *feature = features[propertyName];
    if(feature != nil) {
        if([feature parseData:data])
            [self onValueChanged:feature ofProperty:propertyName];
    }
}

@end

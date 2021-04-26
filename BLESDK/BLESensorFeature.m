//
//  BLESensorFeature.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLESensorFeature.h"

@interface BLESensorFeature() {
    NSData* rawData;
    NSDictionary* config;
}

@implementation BLESensorFeature

- (id)initWithConfig: (NSDictionary*)config {
    return self
}

- (BOOL)parseData: (NSData*)data {
    return @NO
}

@end

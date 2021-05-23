//
//  BLESensorFeature.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLESensorFeature.h"
#import "CSL.h"

@interface BLESensorFeature() {
    NSDictionary* config;
}
@end

@implementation BLESensorFeature

- (id)initWithConfig: (NSDictionary*)_config {
    if(self = [super init]) {
        config = _config;
    }
    return self;
}

- (BOOL)parseData: (NSData*)data {
    if((self.value = csl_decode(data, 0, config)))
        return YES;
    else
        return NO;
}

- (NSString*)name {
    return config[@"name"];
}

- (NSString*)valueString {
    if(!self.value)
        return nil;
    NSString *result;
    if([@"array" isEqual:config[@"type"]]) {
        NSArray *array = (NSArray*)self.value;
        NSMutableArray *valueStringArray = [NSMutableArray array];
        for (NSNumber *number in array) {
            [valueStringArray addObject:[number description]];
        }
        result = [valueStringArray componentsJoinedByString:@","];
    }
    else
        result = [self.value description];
    NSString *unit = config[@"unit"];
    if(unit)
        result = [NSString stringWithFormat:@"%@ %@", result, unit];
    return result;
}

@end

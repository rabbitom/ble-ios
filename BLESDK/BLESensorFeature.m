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
    NSObject *value;
}
- (NSString*)configString: (NSString*)key;
@end

@implementation BLESensorFeature

- (id)initWithConfig: (NSDictionary*)_config {
    if(self = [super init]) {
        config = _config;
    }
    return self;
}

id doConversion(NSObject* src, NSString* operator, id operand) {
    if([operator isEqual:@"divide"]) {
        //if(src.class == NSArray.class) {
            NSMutableArray *arr = [NSMutableArray array];
            for(NSNumber* n in (NSArray*)src) {
                float f = [n floatValue] / [(NSNumber*)operand floatValue];
                [arr addObject: [NSNumber numberWithFloat:f]];
            }
            return arr;
        //}
    }
    return src;
}

- (BOOL)parseData: (NSData*)data {
    if((value = csl_decode(data, 0, config, nil))) {
        NSArray *conversions = config[@"conversions"];
        if(conversions) {
            for(NSDictionary *conversion in conversions) {
                NSArray* operandValue = conversion[@"value"];
                int operandValueLength = (int)[operandValue count];
                Byte operandBytes[operandValueLength];
                for(int i=0; i<operandValueLength; i++) {
                    NSNumber *iNumber = operandValue[i];
                    operandBytes[i] = [iNumber unsignedCharValue];
                }
                NSData* operandData = [NSData dataWithBytes:operandBytes length:operandValueLength];
                id operand = csl_decode(operandData, 0, conversion, nil);
                value = doConversion(value, conversion[@"operator"], operand);
            }
        }
        return YES;
    }
    else
        return NO;
}

- (NSString*)name {
    return [self configString: @"name"];
}

- (int)dimension {
    NSNumber *result = config[@"dimension"];
    if(result)
        return [result intValue];
    else
        return 1;
}

- (NSObject*)value {
    return value;
}

- (NSString*)configString: (NSString*)key {
    NSString *result = config[key];
    return result ? result : @"";
}

- (NSString*)unit {
    return [self configString: @"unit"];
}

- (NSString*)description {
    return [self configString: @"description"];
}

- (NSString*)valueString {
    if(!self.value)
        return @"";
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

- (NSArray*) keys {
    NSArray *fields = config[@"fields"];
    NSMutableArray *result = [NSMutableArray array];
    [fields enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [result addObject: ((NSDictionary*)obj)[@"name"]];
    }];
    return result;
}

@end

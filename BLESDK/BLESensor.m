//
//  BLESensorFeature.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLESensor.h"
#import "CSL.h"

@interface BLESensor()
{
    id value;
}
@end

@implementation BLESensor

- (id)initWithConfig: (NSDictionary*)_config switchable:(BOOL)isSwitchable{
    if(self = [super init]) {
        config = _config;
        _switchable = isSwitchable;
        _state = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString*)name {
    return config[@"name"];
}

- (NSString*)type {
    return config[@"type"];
}

- (NSArray*)attributes {
    return config[@"attributes"];
}

- (NSString*)unit {
    return config[@"unit"];
}

- (id)value {
    return value;
}

- (void)setValue: (id)newValue {
    value = newValue;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLESensor.ValueUpdated" object:self userInfo:@{@"name":self.name, @"value":value}];
}

- (NSString*)valueString {
    if(self.value == nil)
        return @"";
    if([self.value isKindOfClass:[NSArray class]]) {
        NSArray *values = [self.value valueForKeyPath:@"description"];
        return [NSString stringWithFormat:@"[%@]%@", [values componentsJoinedByString:@","], self.unit];
    }
    else if([self.value isKindOfClass:[NSDictionary class]]) {
        NSMutableArray *values = [NSMutableArray array];
        for(NSDictionary *attribute in self.attributes) {
            id attributeValue = self.value[attribute[@"name"]];
            [values addObject:
                 [NSString stringWithFormat:@"%@:%@%@", attribute[@"name"], attributeValue, attribute[@"unit"]]
            ];
        }
        return [values componentsJoinedByString:@", "];
    }
    else
        return [NSString stringWithFormat:@"%@%@", self.value, self.unit];
}

- (void)parseData: (NSData*)data {
    int parseLength = 0;
    self.value = csl_decode(data, 0, config, &parseLength);
}

@end

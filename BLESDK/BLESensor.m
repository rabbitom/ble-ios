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
#import "Events.h"

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

- (NSDictionary*)config {
    return config;
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
    [[NSNotificationCenter defaultCenter] postNotificationName:ValueUpdated object:self userInfo:@{@"name":self.name, @"value":value}];
}

- (NSString*)valueString {
    if(value == nil)
        return @"";
    return csl_format_value(value, config);
}

- (void)parseData: (NSData*)data {
    int parseLength = 0;
    self.value = csl_decode(data, 0, config, &parseLength);
}

@end

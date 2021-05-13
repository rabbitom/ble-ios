//
//  CSL.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/29.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSL.h"

id csl_decode_int16be(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    short result = 0;
    result = (bytes[offset] << 8) | bytes[offset + 1];
    return [NSNumber numberWithShort: result];
}

id csl_decode_uint16be(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    unsigned short result = 0;
    result = (bytes[offset] << 8) | bytes[offset + 1];
    return [NSNumber numberWithUnsignedShort: result];
}

id csl_decode_fixed(NSData* data, int offset, NSDictionary *config) {
    Byte* bytes = (Byte*)[data bytes];
    NSArray *valueArr = config[@"value"];
    NSNumber *byteLength = config[@"byteLength"];
    for(int i=0; i<[byteLength intValue]; i++) {
        id valueItem = valueArr[i];
        if(bytes[i] == [(NSNumber*)valueItem intValue])
            continue;
        else
            return @NO;
    }
    return @YES;
}

id csl_decode_scalar(NSData* data, int offset, NSDictionary *config) {
    NSString *format = config[@"format"];
    if([[format lowercaseString] isEqual: @"uint16be"])
        return csl_decode_uint16be(data, offset);
    else if([[format lowercaseString] isEqual: @"int16be"])
        return csl_decode_int16be(data, offset);
    return nil;
}

id csl_decode_array(NSData* data, int offset, NSDictionary *config) {
    NSMutableArray *result = [NSMutableArray array];
    for(NSDictionary *field in config[@"fields"]) {
        id item = csl_decode(data, offset, field);
        if(item) {
            if(![field[@"type"] isEqual: @"fixed"])
                [result addObject: item];
        }
        NSNumber *byteLength = field[@"byteLength"];
        int fieldLength = byteLength ? [byteLength intValue] : 1;
        offset += fieldLength;
    }
    return result;
}

id csl_decode(NSData *data, int offset, NSDictionary *config) {
    if([config[@"type"] isEqual: @"array"])
        return csl_decode_array(data, offset, config);
    else if([config[@"type"] isEqual: @"fixed"])
        return csl_decode_fixed(data, offset, config);
    else //default: scalar
        return csl_decode_scalar(data, offset, config);
    return nil;
}

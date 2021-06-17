//
//  CSL.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/29.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CSL.h"

id csl_decode_uint8(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    return [NSNumber numberWithUnsignedChar: bytes[offset]];
}

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

id csl_decode_uint16le(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    unsigned short result = 0;
    result = bytes[offset] | (bytes[offset + 1] << 8);
    return [NSNumber numberWithUnsignedShort: result];
}

id csl_decode_uint32be(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    UInt32 result = 0;
    result = (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
    return [NSNumber numberWithUnsignedInt: result];
}

id csl_decode_uint32le(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    UInt32 result = 0;
    result = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
    return [NSNumber numberWithUnsignedInt: result];
}

id csl_decode_int32le(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    SInt32 result = 0;
    result = bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
    return [NSNumber numberWithInt: result];
}

id csl_decode_float32(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    Float32 result = *(Float32*)(bytes + offset);
    return [NSNumber numberWithFloat:result];
}

//temperature
id csl_decode_t16(NSData* data, int offset) {
    Byte* bytes = (Byte*)[data bytes];
    SInt8 digit = ((SInt8*)bytes)[offset];
    UInt8 remainder = bytes[offset+1];
    Float32 result = (Float32)digit + (Float32)remainder / 100;
    return [NSNumber numberWithFloat:result];
}

//pressure
id csl_decode_p40(NSData* data, int offset) {
    double result = [csl_decode_uint32le(data, offset) doubleValue];
    double decimalVal = [csl_decode_uint8(data, offset + 4) doubleValue];
    if (decimalVal < 10) {
        result += decimalVal / 10;
    } else if (decimalVal < 100) {
        result += decimalVal / 100;
    } else {
        result += decimalVal / 1000;
    }
    return [NSNumber numberWithDouble: result];
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
    if(format) {
        format = [format lowercaseString];
        if([format isEqual: @"uint8"])
            return csl_decode_uint8(data, offset);
        else if([format isEqual: @"uint16be"])
            return csl_decode_uint16be(data, offset);
        else if([format isEqual: @"uint16le"])
            return csl_decode_uint16le(data, offset);
        else if([format isEqual: @"int16be"])
            return csl_decode_int16be(data, offset);
        else if([format isEqual: @"uint32be"])
            return csl_decode_uint32be(data, offset);
        else if([format isEqual: @"uint32le"])
            return csl_decode_uint32le(data, offset);
        else if([format isEqual: @"int32le"])
            return csl_decode_int32le(data, offset);
        else if([format isEqual: @"float32"])
            return csl_decode_float32(data, offset);
        else if([format isEqual: @"t16"])
            return csl_decode_t16(data, offset);
        else if([format isEqual: @"p40"])
            return csl_decode_p40(data, offset);
    }
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

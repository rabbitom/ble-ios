//
//  CSL.m
//  BLESDK
//
//  Created by 郝建林 on 2021/4/29.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import "CSL.h"

void checkLength(NSData *data, int offset, int byteLength, int *pLength) {
    if(data.length - offset < byteLength)
        @throw [NSException exceptionWithName:@"Decoding failed" reason:@"too short" userInfo:@{
            @"dataLength":[NSNumber numberWithUnsignedLong:data.length],
            @"offset":[NSNumber numberWithInt:offset],
            @"byteLength":[NSNumber numberWithInt:byteLength]
        }];
    *pLength = byteLength;
}

id csl_value_with_scale(int value, NSNumber *scale) {
    if(scale != nil)
        return [NSNumber numberWithFloat: value * scale.floatValue];
    else
        return [NSNumber numberWithInt: value];
}

id csl_decode_uint(NSData* data, int offset, uint bits, bool le, NSNumber *scale, int *pLength) {
    int byteLength = bits / 8;
    checkLength(data, offset, byteLength, pLength);
    Byte* bytes = (Byte*)[data bytes];
    unsigned int result = 0;
    for(int i=0; i<byteLength; i++) {
        if(le)
            result = result | (bytes[offset + i] << (8 * i));
        else
            result = (result << 8) | bytes[offset + i];
    }
    return csl_value_with_scale(result, scale);
}

id csl_decode_int16(NSData* data, int offset, bool le, NSNumber *scale, int *pLength) {
    checkLength(data, offset, 2, pLength);
    Byte* bytes = (Byte*)[data bytes];
    short result = 0;
    for(int i=0; i<2; i++) {
        if(le)
            result = result | (bytes[offset + i] << (8 * i));
        else
            result = (result << 8) | bytes[offset + i];
    }
    return csl_value_with_scale(result, scale);
}

id csl_decode_int32(NSData* data, int offset, bool le, NSNumber *scale, int *pLength) {
    checkLength(data, offset, 4, pLength);
    Byte* bytes = (Byte*)[data bytes];
    int result = 0;
    for(int i=0; i<4; i++) {
        if(le)
            result = result | (bytes[offset + i] << (8 * i));
        else
            result = (result << 8) | bytes[offset + i];
    }
    return csl_value_with_scale(result, scale);
}

id csl_decode_float32le(NSData* data, int offset, int *pLength) {
    checkLength(data, offset, 4, pLength);
    Byte* bytes = (Byte*)[data bytes];
    Float32 result = *(Float32*)(bytes + offset);
    return [NSNumber numberWithFloat:result];
}

id csl_decode_string(NSData* data, int offset, NSDictionary *config, int *pLength) {
    NSNumber *byteLength = config[@"byteLength"];
    if(byteLength == nil)
        @throw [NSException exceptionWithName:@"Decoding failed" reason:@"byteLength of string not set" userInfo:@{@"config":config}];
    checkLength(data, offset, [byteLength intValue], pLength);
    int length = [byteLength intValue];
    Byte *bytes = (Byte*)[data bytes];
    bytes += offset;
    NSString *encoding = config[@"stringEncoding"];
    if([encoding isEqualToString:@"hex"]) {
        NSMutableString *str = [NSMutableString string];
        NSString *connector = config[@"hexByteConnector"];
        for(int i=0; i<length; i++) {
            NSString *c = [NSString stringWithFormat:@"%@%.2X", i > 0 ? connector : @"", bytes[i]];
            [str appendString:c];
        }
        return str;
    }
    else {
        char chars[length+1];
        for(int i=0; i<length; i++)
            chars[i] = bytes[i];
        chars[length] = 0;
        return [NSString stringWithCString:chars encoding:NSASCIIStringEncoding];
    }
}

id csl_decode_bytes(NSData* data, int offset, NSDictionary *config, int *pLength) {
    NSNumber *byteLength = config[@"byteLength"];
    if(byteLength != nil)
        checkLength(data, offset, [byteLength intValue], pLength);
    else if(data.length > offset) {
        byteLength = [NSNumber numberWithInt:(int)data.length - offset];
        *pLength = [byteLength intValue];
    }
    else
        return nil;
    Byte *bytes = (Byte*)[data bytes];
    return [NSData dataWithBytes:bytes+offset length:[byteLength unsignedIntValue]];
}

id csl_decode_boolean(NSData *data, int offset, int *pLength) {
    checkLength(data, offset, 1, pLength);
    Byte* bytes = (Byte*)[data bytes];
    Byte b = bytes[offset];
    return [NSNumber numberWithBool: b != 0];
}

id csl_decode_enum(NSData *data, int offset, NSArray *values, int *pLength) {
    checkLength(data, offset, 1, pLength);
    Byte* bytes = (Byte*)[data bytes];
    Byte b = bytes[offset];
    NSUInteger index = [values indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dict = obj;
        return [(NSNumber*)dict[@"value"] unsignedCharValue] == b;
    }];
    NSDictionary *item = values[index];
    return item[@"name"];
}

id csl_get_variable_type(NSDictionary *value, NSDictionary *config) {
    NSString *typeName = value[config[@"typeName"]];
    if(typeName) {
        NSArray *types = config[@"types"];
        NSUInteger typeIndex = [types indexOfObjectPassingTest:^BOOL(NSDictionary *type, NSUInteger idx, BOOL * _Nonnull stop) {
            return [type[@"name"] isEqualToString:typeName];
        }];
        if(typeIndex != NSNotFound)
            return types[typeIndex];
        else
            @throw [NSException exceptionWithName:@"csl failed" reason:@"variable type not found" userInfo:@{@"config": config}];
    }
    else
        @throw [NSException exceptionWithName:@"csl failed" reason:@"type name could not be determined" userInfo:@{@"config": config}];
}

//for decode
id csl_remap_attributes(NSDictionary *value, NSArray *map) {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    for(id entry in map) {
        if([entry isKindOfClass:[NSDictionary class]]) {
            NSString *key = ((NSDictionary*)entry)[@"key"];
            NSArray *attributes = ((NSDictionary*)entry)[@"attributes"];
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            for(NSString *attr in attributes)
                dict[attr] = value[attr];
            res[key] = dict;
        }
        else if([entry isKindOfClass:[NSString class]])
            res[entry] = value[entry];
        else
            @throw [NSException exceptionWithName:@"decoding failed" reason:@"map entry should be a string or dictionary" userInfo:@{@"map":map}];
    }
    return res;
}

//for encode
id csl_unmap_attributes(NSDictionary *value, NSArray *map) {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    for(id entry in map) {
        if([entry isKindOfClass:[NSDictionary class]]) {
            NSString *key = ((NSDictionary*)entry)[@"key"];
            NSArray *attributes = ((NSDictionary*)entry)[@"attributes"];
            NSMutableDictionary *dict = value[key];
            for(NSString *attr in attributes)
                res[attr] = dict[attr];
        }
        else if([entry isKindOfClass:[NSString class]])
            res[entry] = value[entry];
        else
            @throw [NSException exceptionWithName:@"encoding failed" reason:@"map entry should be a string or dictionary" userInfo:@{@"map":map}];
    }
    return res;
}

id csl_decode_object(NSData *data, int offset, NSDictionary *config, int *pLength) {
    NSNumber *byteLength = config[@"byteLength"];
    if(byteLength != nil)
        checkLength(data, offset, [byteLength intValue], pLength);
    NSArray *attributes = config[@"attributes"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    int totalLength = 0;
    for(NSDictionary *_attr in attributes) {
        NSDictionary *attr = _attr;
        NSString *key = attr[@"name"];
        if([attr[@"type"] isEqualToString:@"variable"])
            attr = csl_get_variable_type(dict, attr);
        int attrLength = 0;
        dict[key] = csl_decode(data, offset + totalLength, attr, &attrLength);
        totalLength += attrLength;
        if(offset + totalLength == data.length)
            break; //skip remaining attributes, without checking for optional
    }
    *pLength = totalLength;
    if(config[@"remap"])
        return csl_remap_attributes(dict, config[@"remap"]);
    else
        return dict;
}

id csl_decode_bitmask(NSData *data, int offset, NSArray *attributes, int *pLength) {
    checkLength(data, offset, 1, pLength);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    Byte* bytes = (Byte*)[data bytes];
    Byte b = bytes[offset];
    for(NSDictionary *attr in attributes) {
        NSString *key = attr[@"name"];
        Byte mask = [(NSNumber*)attr[@"mask"] unsignedCharValue];
        int maskShift = 0;
        while(((1 << maskShift) & mask) == 0)
            maskShift++;
        Byte attrByte = (b & mask) >> maskShift;
        NSData *attrData = [NSData dataWithBytes:&attrByte length:1];
        int attrLength = 0;
        id attrValue = csl_decode(attrData, 0, attr, &attrLength);
        [dict setObject:attrValue forKey:key];
    }
    return dict;
}

id csl_decode_array(NSData *data, int offset, NSDictionary *config, int *pLength) {
    NSMutableArray *result = [NSMutableArray array];
    NSNumber *byteLength = config[@"byteLength"];
    if(byteLength == nil)
        @throw [NSException exceptionWithName:@"Decoding failed" reason:@"byteLength of array not set" userInfo:@{@"config":config}];
    checkLength(data, offset, [byteLength intValue], pLength);
    NSDictionary *itemConfig = config[@"arrayItem"];
    int totalLength = 0;
    while(totalLength < [byteLength intValue]) {
        int itemLength = 0;
        id itemValue = csl_decode(data, offset + totalLength, itemConfig, &itemLength);
        [result addObject:itemValue];
        totalLength += itemLength;
    }
    *pLength = totalLength;
    return result;
}

id csl_decode(NSData *data, int offset, NSDictionary *config, int *pLength) {
    NSString *type = config[@"type"];
    if([type isEqual: @"uint8"])
        return csl_decode_uint(data, offset, 8, false, config[@"scale"], pLength);
    else if([type isEqual: @"uint16be"])
        return csl_decode_uint(data, offset, 16, false, config[@"scale"], pLength);
    else if([type isEqual: @"uint16le"])
        return csl_decode_uint(data, offset, 16, true, config[@"scale"], pLength);
    else if([type isEqual: @"int16be"])
        return csl_decode_int16(data, offset, false, config[@"scale"], pLength);
    else if([type isEqual: @"int16le"])
        return csl_decode_int16(data, offset, true, config[@"scale"], pLength);
    else if([type isEqual: @"uint32be"])
        return csl_decode_uint(data, offset, 32, false, config[@"scale"], pLength);
    else if([type isEqual: @"uint32le"])
        return csl_decode_uint(data, offset, 32, true, config[@"scale"], pLength);
    else if([type isEqual: @"int32be"])
        return csl_decode_int32(data, offset, false, config[@"scale"], pLength);
    else if([type isEqual: @"int32le"])
        return csl_decode_int32(data, offset, true, config[@"scale"], pLength);
    else if([type isEqual: @"float32le"])
        return csl_decode_float32le(data, offset, pLength);
    else if([type isEqual: @"string"])
        return csl_decode_string(data, offset, config, pLength);
    else if([type isEqual: @"bytes"])
        return csl_decode_bytes(data, offset, config, pLength);
    else if([type isEqual: @"boolean"])
        return csl_decode_boolean(data, offset, pLength);
    else if([type isEqual: @"enum"])
        return csl_decode_enum(data, offset, config[@"values"], pLength);
    else if([type isEqual: @"object"])
        return csl_decode_object(data, offset, config, pLength);
    else if([type isEqual: @"bitmask"])
        return csl_decode_bitmask(data, offset, config[@"attributes"], pLength);
    else if([type isEqual: @"array"])
        return csl_decode_array(data, offset, config, pLength);
    else
        @throw [NSException exceptionWithName:@"Decoding failed" reason:@"type not supported" userInfo:@{@"config":config}];
}

int hex2int(unichar c) {
    if(c >= '0' && c <= '9')
        return c - '0';
    else if(c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    else if(c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    else
        return -1;
}

NSData *csl_parse_hex_str(NSString* str) {
    NSMutableData *res = [NSMutableData data];
    int i = 0;
    str = [str lowercaseString];
    if([[str substringToIndex:2] isEqualToString: @"0x"])
        i = 2;
    while(i < str.length) {
        int n = hex2int([str characterAtIndex:i++]);
        if(n >= 0) {
            if(i < str.length) {
                int n1 = hex2int([str characterAtIndex:i++]);
                if(n1 >= 0)
                    n = n * 16 + n1;
            }
            uint8_t b = n;
            [res appendBytes:&b length:1];
        }
    }
    return res;
}

NSData *csl_encode_int(NSNumber *value, uint bits, BOOL le, NSNumber *scale) {
    int n;
    if(scale)
        n = [value floatValue] / [scale floatValue];
    else
        n = [value intValue];
    uint length = bits/8;
    Byte bytes[length];
    for(int i=0; i<length; i++) {
        Byte b = n & 0xFF;
        if(le)
            bytes[i] = b;
        else
            bytes[length-1-i] = b;
        n = n >> 8;
    }
    return [NSData dataWithBytes:bytes length:length];
}

NSData *csl_encode_float32le(NSNumber *value, NSNumber *scale) {
    float v = [value floatValue];
    if(scale)
        v = v / [scale floatValue];
    return [NSData dataWithBytes:&v length:sizeof(v)];
}

NSData *csl_encode_string(NSString *str, NSUInteger length, NSString *encoding) {
    Byte bytes[length];
    NSUInteger usedLength = 0;
    if([encoding isEqualToString:@"hex"]) {
        NSData *data = csl_parse_hex_str(str);
        Byte *hexBytes = (Byte*)[data bytes];
        NSUInteger maxLength = MIN(length, data.length);
        while(usedLength < maxLength) {
            bytes[usedLength] = hexBytes[usedLength];
            usedLength++;
        }
    }
    else
        [str getBytes:bytes maxLength:length usedLength:&usedLength encoding:NSASCIIStringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, str.length) remainingRange:nil];
    while(usedLength < length)
        bytes[usedLength++] = 0;
    return [NSData dataWithBytes:bytes length:length];
}

NSData *csl_encode_boolean(NSNumber *v) {
    Byte b = [v boolValue] ? 1 : 0;
    return [NSData dataWithBytes:&b length:1];
}

NSData *csl_encode_enum(NSString *name, NSArray *values) {
    NSUInteger index = [values indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary* item = obj;
        return [name isEqualToString:item[@"name"]];
    }];
    if(index >= 0) {
        NSDictionary *enumItem = values[index];
        NSNumber *enumValue = enumItem[@"value"];
        Byte b = [enumValue unsignedCharValue];
        return [NSData dataWithBytes:&b length:1];
    }
    else
        @throw [NSException exceptionWithName:@"Encoding failed" reason:@"enum name not found" userInfo:@{@"values":values,@"name":name}];
}

NSData *csl_encode_object(NSDictionary* value, NSArray *fields) {
    NSMutableData *data = [NSMutableData data];
    for(NSDictionary *_field in fields) {
        NSDictionary *field = _field;
        id fieldValue = field[@"value"];
        if(fieldValue == nil) {
            NSString* fieldName = field[@"name"];
            fieldValue = value[fieldName];
            if(fieldValue == nil) {
                NSDictionary *calcConfig = field[@"calc"];
                if(calcConfig) {
#pragma mark todo: calc
                    @throw [NSException exceptionWithName:@"Encoding failed" reason:@"calc not implemented" userInfo:@{@"field":field}];
                }
                else {
                    NSNumber *optional = field[@"optional"];
                    if([optional boolValue])
                        continue;
                    else
                        @throw [NSException exceptionWithName:@"Encoding failed" reason:@"value not found" userInfo:@{@"field":field}];
                }
            }
        }
        if([field[@"type"] isEqualToString:@"variable"])
            field = csl_get_variable_type(value, field);
        [data appendData:csl_encode(fieldValue,field)];
    }
    return data;
}

NSData *csl_encode_bitmask(NSDictionary *value, NSArray *attributes) {
    Byte b = 0;
    for(NSDictionary *attr in attributes) {
        NSData *attrData = csl_encode(value[attr[@"name"]], attr);
        Byte attrValue = ((Byte*)[attrData bytes])[0];
        NSNumber *mask = attr[@"mask"];
        int maskValue = [mask intValue];
        int maskShift = 0;
        while(((1 << maskShift) & maskValue) == 0)
            maskShift++;
        b |= attrValue << maskShift;
    }
    return [NSData dataWithBytes:&b length:1];
}

NSData *csl_encode_array(NSArray *value, NSDictionary *itemConfig) {
    NSMutableData *data = [NSMutableData data];
    for(id itemValue in value) {
        NSData *itemData = csl_encode(itemValue, itemConfig);
        [data appendData:itemData];
    }
    return data;
}

NSData* csl_encode(id value, NSDictionary *config) {
    NSString *type = config[@"type"];
    if(type == nil)
        @throw [NSException exceptionWithName:@"Encoding failed" reason:@"type not set" userInfo:@{@"config":config}];
    else if([type isEqualToString:@"uint8"]) {
        if([value isKindOfClass:[NSNumber class]])
            return csl_encode_int((NSNumber*)value, 8, false, config[@"scale"]);
        else if([value isKindOfClass:[NSString class]]) {
            NSData *data = csl_parse_hex_str((NSString*)value);
            if(data.length != 1)
                @throw [NSException exceptionWithName:@"Encoding failed" reason:@"value length error" userInfo:@{@"config":config,@"value":value}];
            return data;
        }
        else
            @throw [NSException exceptionWithName:@"Encoding failed" reason:@"value class error" userInfo:@{@"config":config,@"value":value}];
    }
    else if([type isEqualToString:@"uint16be"])
        return csl_encode_int((NSNumber*)value, 16, false, config[@"scale"]);
    else if([type isEqualToString:@"uint16le"])
        return csl_encode_int((NSNumber*)value, 16, true, config[@"scale"]);
    else if([type isEqualToString:@"int16be"])
        return csl_encode_int((NSNumber*)value, 16, false, config[@"scale"]);
    else if([type isEqualToString:@"int16le"])
        return csl_encode_int((NSNumber*)value, 16, true, config[@"scale"]);
    else if([type isEqualToString:@"uint32be"])
        return csl_encode_int((NSNumber*)value, 32, false, config[@"scale"]);
    else if([type isEqualToString:@"uint32le"])
        return csl_encode_int((NSNumber*)value, 32, true, config[@"scale"]);
    else if([type isEqualToString:@"int32be"])
        return csl_encode_int((NSNumber*)value, 32, false, config[@"scale"]);
    else if([type isEqualToString:@"int32le"])
        return csl_encode_int((NSNumber*)value, 32, true, config[@"scale"]);
    else if([type isEqualToString:@"float32le"])
        return csl_encode_float32le((NSNumber*)value, config[@"scale"]);
    else if([type isEqualToString:@"string"]) {
        NSNumber *length = config[@"byteLength"];
        if(length == nil)
            @throw [NSException exceptionWithName:@"Encoding failed" reason:@"byte length of string not set" userInfo:@{@"config":config,@"value":value}];
        return csl_encode_string((NSString*)value, [length unsignedIntValue], config[@"stringEncoding"]);
    }
    else if([type isEqualToString:@"bytes"]) {
        if([value isKindOfClass:[NSData class]])
            return value;
        else
            @throw [NSException exceptionWithName:@"Encoding failed" reason:@"value class  error" userInfo:@{@"config":config}];
    }
    else if([type isEqualToString:@"boolean"])
        return csl_encode_boolean(value);
    else if([type isEqualToString:@"enum"])
        return csl_encode_enum(value, config[@"values"]);
    else if([type isEqualToString:@"object"]) {
        if(config[@"remap"])
            value = csl_unmap_attributes(value, config[@"remap"]);
        return csl_encode_object(value, config[@"attributes"]);
    }
    else if([type isEqualToString:@"bitmask"])
        return csl_encode_bitmask(value, config[@"attributes"]);
    else if([type isEqualToString:@"array"])
        return csl_encode_array(value, config[@"arrayItem"]);
    else
        @throw [NSException exceptionWithName:@"Encoding failed" reason:@"type not supported" userInfo:@{@"config":config}];
}

NSString *csl_format_value(id value, NSDictionary *config) {
    if(value == nil)
        return nil;
    NSString *res;
    if([config[@"type"] isEqualToString:@"array"]) {
        //[value isKindOfClass:[NSArray class]]
        NSMutableArray *values = [NSMutableArray array];
        for(id valueItem in (NSArray*)value)
            [values addObject: csl_format_value(valueItem, config[@"arrayItem"])];
        res = [NSString stringWithFormat:@"[%@]", [values componentsJoinedByString:@","]];
    }
    else if([config[@"type"] isEqualToString:@"object"] && [config[@"objectType"] isEqualToString:@"booleans"]) {
        NSArray *keys = [(NSDictionary*)value keysSet];
        return keys.count ? @"..." : @"-";
    }
    else if([value isKindOfClass:[NSDictionary class]]) {
        //config.type is object or bitmask
        NSMutableArray *values = [NSMutableArray array];
        for(NSDictionary *attribute in config[@"attributes"]) {
            id attributeValue = ((NSDictionary*)value)[attribute[@"name"]];
            [values addObject: [NSString stringWithFormat:@"%@=%@", attribute[@"name"], csl_format_value(attributeValue, attribute)]];
        }
        return [values componentsJoinedByString:@", "];
    }
    else if(config[@"decimals"]) {
        NSNumber *decimals = config[@"decimals"];
        NSString *formatString = [NSString stringWithFormat:@"%%.%df", [decimals intValue]];
        res = [NSString stringWithFormat:formatString, [(NSNumber*)value floatValue]];
    }
    else
        res = [(NSObject*)value description];
    if(config[@"unit"])
        return [res stringByAppendingString:config[@"unit"]];
    else
        return res;
}

@implementation NSDictionary (KeysSet)

- (NSArray*)keysSet {
    return [[self keysOfEntriesPassingTest:^BOOL(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        return [(NSNumber*)obj boolValue];
    }] allObjects];
}

@end


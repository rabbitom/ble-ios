//
//  BLESDKTests.m
//  BLESDKTests
//
//  Created by 郝建林 on 2021/5/13.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BLESDK/CSL.h"
#import "BLESDK/BLESensorFeature.h"

void assertArrayEql(NSData *data, uint length, Byte *arr) {
    XCTAssertEqual(data.length, length);
    Byte *bytes = (Byte*)[data bytes];
    for(int i=0; i<length; i++)
        XCTAssertEqual(bytes[i], arr[i]);
}

@interface BLESDKTests : XCTestCase

@end

@implementation BLESDKTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testDecode_uint8_scale {
    int length = 0;
    Byte bytes[] = {2};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"uint8",
        @"scale": @100
    }, &length);
    XCTAssertEqual([n intValue], 200);
    XCTAssertEqual(length, 1);
}

- (void)testDecode_int16le {
    int length = 0;
    Byte bytes[] = {0xFE, 0xFF};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"int16le"
    }, &length);
    XCTAssertEqual([n intValue], -2);
    XCTAssertEqual(length, 2);
}

- (void)testDecode_int16be {
    int length = 0;
    Byte bytes[] = {0xFF, 0xFE};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"int16be"
    }, &length);
    XCTAssertEqual([n intValue], -2);
    XCTAssertEqual(length, 2);
}

- (void)testDecode_int32le {
    int length = 0;
    Byte bytes[] = {0xFE, 0xFF, 0xFF, 0xFF};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"int32le"
    }, &length);
    XCTAssertEqual([n intValue], -2);
    XCTAssertEqual(length, 4);
}

- (void)testDecode_int32be {
    int length = 0;
    Byte bytes[] = {0xFF, 0xFF, 0xFF, 0xFE};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"int32be"
    }, &length);
    XCTAssertEqual([n intValue], -2);
    XCTAssertEqual(length, 4);
}

- (void)testDecode_uint16le {
    int length = 0;
    Byte bytes[] = {0x01, 0x00};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"uint16le"
    }, &length);
    XCTAssertEqual([n intValue], 1);
    XCTAssertEqual(length, 2);
}

- (void)testDecode_uint16be {
    int length = 0;
    Byte bytes[] = {0x00, 0x01};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"uint16be"
    }, &length);
    XCTAssertEqual([n intValue], 1);
    XCTAssertEqual(length, 2);
}

- (void)testDecode_uint32le {
    int length = 0;
    Byte bytes[] = {1, 0, 0, 0};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"uint32le"
    }, &length);
    XCTAssertEqual([n intValue], 1);
    XCTAssertEqual(length, 4);
}

- (void)testDecode_uint32be {
    int length = 0;
    Byte bytes[] = {0, 0, 0, 1};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"uint32be"
    }, &length);
    XCTAssertEqual([n intValue], 1);
    XCTAssertEqual(length, 4);
}

- (void)testDecode_float32le {
    int length = 0;
    Byte bytes[] = {0x00, 0x00, 0xD0, 0x40};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *n = csl_decode(data, 0, @{
        @"type": @"float32le"
    }, &length);
    XCTAssertEqual([n floatValue], 6.5);
    XCTAssertEqual(length, 4);
}

- (void)testDecode_string {
    int length = 0;
    Byte bytes[] = {0x30, 0x31, 0x32};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSString *str = csl_decode(data, 0, @{
        @"type": @"string",
        @"byteLength": @3
    }, &length);
    XCTAssertTrue([str isEqualToString:@"012"]);
    XCTAssertEqual(length, 3);
}

- (void)testDecode_string_hex {
    int length = 0;
    Byte bytes[] = {0, 1, 2};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSString *str = csl_decode(data, 0, @{
        @"type": @"string",
        @"byteLength": @3,
        @"stringEncoding": @"hex",
        @"hexByteConnector": @":"
    }, &length);
    XCTAssertTrue([str isEqualToString:@"00:01:02"]);
    XCTAssertEqual(length, 3);
}

- (void)testDecode_bytes_byteLength {
    int length = 0;
    Byte bytes[] = {0, 1, 2};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *bytesDataWithByteLength = csl_decode(data, 0, @{
        @"type": @"bytes",
        @"byteLength": @1
    }, &length);
    Byte bytesWithByteLength[] = {0};
    assertArrayEql(bytesDataWithByteLength, 1, bytesWithByteLength);
    XCTAssertEqual(length, 1);
}

- (void)testDecode_bytes_withoutLength {
    int length = 0;
    Byte bytes[] = {0, 1, 2};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *bytesDataWithoutLength = csl_decode(data, 1, @{
        @"type": @"bytes"
    }, &length);
    Byte bytesWithoutLength[] = {1, 2};
    assertArrayEql(bytesDataWithoutLength, 2, bytesWithoutLength);
    XCTAssertEqual(length, 2);
}

- (void)testDecode_boolean {
    int length = 0;
    Byte bytes[] = {1, 0};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSNumber *y = csl_decode(data, 0, @{
        @"type": @"boolean"
    }, &length);
    XCTAssertEqual(length, 1);
    XCTAssertTrue([y boolValue]);
    NSNumber *n = csl_decode(data, 1, @{
        @"type": @"boolean"
    }, &length);
    XCTAssertEqual(length, 1);
    XCTAssertFalse([n boolValue]);
}

- (void)testDecode_enum {
    int length = 0;
    Byte bytes[] = {1};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSString *value = csl_decode(data, 0, @{
        @"type": @"enum",
        @"values": @[
            @{@"name": @"a", @"value": @1},
            @{@"name": @"b", @"value": @2},
        ]
    }, &length);
    XCTAssertEqual(value, @"a");
    XCTAssertEqual(length, 1);
}

- (void)testDecode_object {
    int length = 0;
    Byte bytes[] = {1, '0', '1', '2'};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSDictionary *value = csl_decode(data, 0, @{
        @"type":@"object",
        @"attributes":@[
            @{@"name":@"n",@"type":@"uint8"},
            @{@"name":@"s",@"type":@"string",@"byteLength":@3}
        ]
    }, &length);
    XCTAssertEqual([(NSNumber*)value[@"n"] intValue], 1);
    XCTAssertTrue([(NSString*)value[@"s"] isEqualToString:@"012"]);
    XCTAssertEqual(length, 4);

}

- (void)testDecode_bitmask {
    int length = 0;
    Byte bytes[] = {0x21};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSDictionary *value = csl_decode(data, 0, @{
        @"type":@"bitmask",
        @"attributes":@[
            @{@"name":@"a",@"type":@"boolean",@"mask":@1}, //0x01
            @{@"name":@"b",@"type":@"boolean",@"mask":@2}, //0x00
            @{@"name":@"c",@"type":@"uint8",@"mask":@0xF0} //0x20
        ]
    }, &length);
    XCTAssertTrue([(NSNumber*)value[@"a"] boolValue]);
    XCTAssertFalse([(NSNumber*)value[@"b"] boolValue]);
    XCTAssertEqual([(NSNumber*)value[@"c"] intValue], 0x2);
    XCTAssertEqual(length, 1);
}

- (void)testDecode_array {
    int length = 0;
    Byte bytes[] = {1,2,3};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSArray *array = csl_decode(data, 0, @{
        @"type":@"array",
        @"byteLength":@3,
        @"arrayItem":@{
            @"type":@"uint8"
        }
    }, &length);
    XCTAssertEqual(array.count, 3);
    for(int i=0; i<3; i++)
        XCTAssertEqual([(NSNumber*)array[i] intValue], bytes[i]);
    XCTAssertEqual(length, 3);
}

- (void)testEncode_uint8 {
    NSData *data = csl_encode(@8, @{@"type":@"uint8"});
    Byte bytes[] = {8};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_uint8_scale {
    NSData *data = csl_encode(@0.8, @{@"type":@"uint8",@"scale":@0.1});
    Byte bytes[] = {8};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_uint8_hex {
    NSData *data = csl_encode(@"0xF1", @{@"type":@"uint8"});
    Byte bytes[] = {0xF1};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_uint16be {
    NSData *data = csl_encode(@0x11FF, @{@"type":@"uint16be"});
    Byte bytes[] = {0x11, 0xFF};
    assertArrayEql(data, sizeof(bytes), bytes);}

- (void)testEncode_int16be {
    NSData *data = csl_encode(@-2, @{@"type":@"int16be"});
    Byte bytes[] = {0xFF, 0xFE};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_uint16le {
    NSData *data = csl_encode(@0x11FF, @{@"type":@"uint16le"});
    Byte bytes[] = {0xFF, 0x11};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_int16le {
    NSData *data = csl_encode(@-2, @{@"type":@"int16le"});
    Byte bytes[] = {0xFE, 0xFF};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_int32be {
    NSData *data = csl_encode(@-2, @{@"type":@"int32be"});
    Byte bytes[] = {0xFF, 0xFF, 0xFF, 0xFE};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_int32le {
    NSData *data = csl_encode(@-2, @{@"type":@"int32le"});
    Byte bytes[] = {0xFE, 0xFF, 0xFF, 0xFF};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_uint32be {
    NSData *data = csl_encode(@0xFFFFFFFE, @{@"type":@"uint32be"});
    Byte bytes[] = {0xFF, 0xFF, 0xFF, 0xFE};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_uint32le {
    NSData *data = csl_encode(@0xFFFFFFFE, @{@"type":@"uint32le"});
    Byte bytes[] = {0xFE, 0xFF, 0xFF, 0xFF};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_float32le {
    NSData *data = csl_encode(@6.5, @{@"type":@"float32le"});
    Byte bytes[] = {0x00, 0x00, 0xD0, 0x40};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_string_hex {
    NSData *data = csl_encode(@"00:01:02", @{
        @"type":@"string",
        @"stringEncoding":@"hex",
        @"byteLength":@3
    });
    Byte bytes[] = {0, 1, 2};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_enum {
    NSData *data = csl_encode(@"a", @{
        @"type": @"enum",
        @"values": @[
            @{@"name": @"a", @"value": @1},
            @{@"name": @"b", @"value": @2},
    ]});
    Byte bytes[] = {1};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_object {
    NSData *data = csl_encode(@{@"n":@1,@"s":@"012"}, @{
        @"type":@"object",
        @"attributes":@[
            @{@"name":@"n",@"type":@"uint8"},
            @{@"name":@"s",@"type":@"string",@"byteLength":@3}
        ]
    });
    Byte bytes[] = {1, '0', '1', '2'};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_bitmask {
    NSData *data = csl_encode(@{@"a":@YES,@"b":@NO,@"c":@0x2}, @{
        @"type":@"bitmask",
        @"attributes":@[
            @{@"name":@"a",@"type":@"boolean",@"mask":@1}, //0x01
            @{@"name":@"b",@"type":@"boolean",@"mask":@2}, //0x00
            @{@"name":@"c",@"type":@"uint8",@"mask":@0xF0} //0x20
        ]
    });
    Byte bytes[] = {0x21};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testEncode_array {
    NSData *data = csl_encode(@[@1,@2,@3], @{
        @"type":@"array",
        @"arrayItem":@{
            @"type":@"uint8"
        }
    });
    Byte bytes[] = {1,2,3};
    assertArrayEql(data, sizeof(bytes), bytes);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end

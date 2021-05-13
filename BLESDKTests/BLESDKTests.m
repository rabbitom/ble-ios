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

@interface BLESDKTests : XCTestCase

@end

@implementation BLESDKTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testUInt16BE {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    Byte bytes[] = {0x12, 0x34};
    NSNumber *number = (NSNumber*)csl_decode([NSData dataWithBytes:bytes length:2], 0, @{
        @"format": @"UInt16BE",
        @"byteLength": @2
                                                         });
    XCTAssertEqual([number unsignedShortValue], 0x1234);
}

- (void)testInt16BE {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    Byte bytes[] = {0x80, 0x00};
    NSNumber *number = (NSNumber*)csl_decode([NSData dataWithBytes:bytes length:2], 0, @{
        @"format": @"Int16BE",
        @"byteLength": @2
                                                         });
    XCTAssertEqual([number shortValue], -0x8000);
}

- (void)testFixed {
    Byte bytes[] = {0x12, 0x34};
    NSNumber *number = (NSNumber*)csl_decode([NSData dataWithBytes:bytes length:2], 0, @{
        @"type": @"fixed",
        @"value": @[@0x12, @0x34],
        @"byteLength": @2
                                                         });
    XCTAssertTrue([number boolValue]);
}

- (void)testBLESensorFeature {
    BLESensorFeature *feature = [[BLESensorFeature alloc] initWithConfig:@{
        @"type": @"array",
        @"length": @8,
        @"fields": @[
            @{
                @"type": @"fixed",
                @"value": @[@0x12, @0x34],
                @"byteLength": @2
            },
            @{
                @"name": @"x",
                @"format": @"Int16BE",
                @"byteLength": @2
            },
            @{
                @"name": @"y",
                @"format": @"Int16BE",
                @"byteLength": @2
            },
            @{
                @"name": @"z",
                @"format": @"Int16BE",
                @"byteLength": @2
            }
        ]
    }];
    Byte bytes[] = {0x12,0x34,0x56,0x78,0x9A,0xBC,0xDE,0xF0};
    XCTAssertTrue([feature parseData:[NSData dataWithBytes:bytes length:8]]);
    NSArray *value = (NSArray*)[feature value];
    XCTAssertEqual([value count], 3);
    XCTAssertEqual([value[0] shortValue], 0x5678);
    XCTAssertEqual([value[1] shortValue], 0x9ABC - 0x10000);
    XCTAssertEqual([value[2] shortValue], 0xDEF0 - 0x10000);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end

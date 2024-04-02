//
//  BLESensorFeature.h
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#ifndef BLESensor_h
#define BLESensor_h

#import <Foundation/Foundation.h>

@interface BLESensor : NSObject
{
    NSDictionary *config;
}

@property (readonly) NSString* name;
@property (readonly) NSString* type;
@property (readonly) NSString* unit;
@property (readonly) NSArray* attributes;

@property (readonly) NSMutableDictionary* settings;
@property (readonly) NSMutableDictionary* status;

@property id value;
@property (readonly) NSString* valueString;

@property BOOL switchable; //是否可开关
@property BOOL isOn; //是否开启

- (id)initWithConfig: (NSDictionary*)config switchable:(BOOL)isSwitchable;
- (void)parseData: (NSData*)data;

@end

#endif /* BLESensorFeature_h */

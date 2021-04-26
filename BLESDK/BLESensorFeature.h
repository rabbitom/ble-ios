//
//  BLESensorFeature.h
//  BLESDK
//
//  Created by 郝建林 on 2021/4/26.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#ifndef BLESensorFeature_h
#define BLESensorFeature_h

#import <Foundation/Foundation.h>

@interface BLESensorFeature : NSObject

@property NSString* name;

@property BOOL enabled;

@property NSObject* value;

- (id)initWithConfig: (NSDictionary*)config;
- (BOOL)parseData: (NSData*)data;

@end

#endif /* BLESensorFeature_h */

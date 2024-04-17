//
//  CSLDevice.h
//  BLESDK
//
//  Created by Tom on 2024/4/17.
//  Copyright © 2024 CoolTools. All rights reserved.
//

#ifndef CSLDevice_h
#define CSLDevice_h

@interface CSLDevice : NSObject
{
    NSDictionary *metadata;
    NSMutableDictionary *state;
}

@property (readonly) NSMutableDictionary *state;
@property (readonly) BOOL isBusy;
@property (readonly) BOOL isPolling;

- (id)initWithMetadata: (NSDictionary*)metadata;

- (void)beforeReady;
- (void)onReady;
- (void)sendData: (NSData*)data;
- (void)onReceivedData: (NSData*)data;

- (NSDictionary*)featureWithName: (NSString*)name;
- (BOOL)callFeature: (NSString*)name withValue: (id)value;
- (void)onFeatureResponse: (NSString*)name value:(id)value;
- (id)stateValueOf: (NSDictionary*)config formatted: (BOOL)format;

@end

#endif /* CSLDevice_h */

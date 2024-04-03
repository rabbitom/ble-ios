//
//  CSL.h
//  BLESDK
//
//  Created by 郝建林 on 2021/4/29.
//  Copyright © 2021 CoolTools. All rights reserved.
//

#ifndef CSL_h
#define CSL_h

id csl_decode(NSData *data, int offset, NSDictionary *config, int *length);

NSData* csl_encode(id value, NSDictionary *config);

NSData *csl_parse_hex_str(NSString* str);

NSString *csl_format_value(id value, NSDictionary *config);

#endif /* CSL_h */

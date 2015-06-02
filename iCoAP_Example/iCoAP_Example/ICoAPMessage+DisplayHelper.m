//
//  ICoAPMessage+DisplayHelper.m
//  iCoAP_Example
//
//  Created by Patrick Butkiewicz on 6/2/15.
//  Copyright (c) 2015 croX Interactive. All rights reserved.
//

#import "ICoAPMessage+DisplayHelper.h"

@implementation ICoAPMessage (DisplayHelper)

+ (NSString *)optionDisplayStringFromOptionDelta:(uint)delta {
    switch (delta) {
        case IC_IF_MATCH:       return @"If Match";
        case IC_URI_HOST:       return @"URI Host";
        case IC_ETAG:           return @"ETAG";
        case IC_IF_NONE_MATCH:  return @"If None Match";
        case IC_URI_PORT:       return @"URI Port";
        case IC_LOCATION_PATH:  return @"Location Path";
        case IC_URI_PATH:       return @"URI Path";
        case IC_CONTENT_FORMAT: return @"Content Format";
        case IC_MAX_AGE:        return @"Max Age";
        case IC_URI_QUERY:      return @"URI Query";
        case IC_ACCEPT:         return @"Accept";
        case IC_LOCATION_QUERY: return @"Location Query";
        case IC_PROXY_URI:      return @"Proxy URI";
        case IC_PROXY_SCHEME:   return @"Proxy Scheme";
        case IC_BLOCK2:         return @"Block 2";
        case IC_BLOCK1:         return @"Block 1";
        case IC_SIZE2:          return @"Size 2";
        case IC_OBSERVE:        return @"Observe";
        case IC_SIZE1:          return @"Size 1";
        default:                return [NSString stringWithFormat:@"Unknown: %i", delta];
    }
}

- (NSString *)typeDisplayString {
    switch (self.type) {
        case IC_CONFIRMABLE:        return @"Confirmable (CON)";
        case IC_NON_CONFIRMABLE:    return @"Non Confirmable (NON)";
        case IC_ACKNOWLEDGMENT:     return @"Acknowledgment (ACK)";
        case IC_RESET:              return @"Reset (RES)";
        default:                    return [NSString stringWithFormat:@"Unknown: %i", self.type];
    }
}

- (NSString *)codeDisplayString {
    switch (self.code) {
        case IC_EMPTY:                          return @"Empty";
        case IC_CREATED:                        return @"Created";
        case IC_DELETED:                        return @"Deleted";
        case IC_VALID:                          return @"Valid";
        case IC_CHANGED:                        return @"Changed";
        case IC_CONTENT:                        return @"Content";
        case IC_BAD_REQUEST:                    return @"Bad Request";
        case IC_UNAUTHORIZED:                   return @"Unauthorized";
        case IC_BAD_OPTION:                     return @"Bad Option";
        case IC_FORBIDDEN:                      return @"Forbidden";
        case IC_NOT_FOUND:                      return @"Not Found";
        case IC_METHOD_NOT_ALLOWED:             return @"Method Not Allowed";
        case IC_NOT_ACCEPTABLE:                 return @"Not Acceptable";
        case IC_PRECONDITION_FAILED:            return @"Precondition Failed";
        case IC_REQUEST_ENTITY_TOO_LARGE:       return @"Request Entity Too Large";
        case IC_UNSUPPORTED_CONTENT_FORMAT:     return @"Unsupported Content Format";
        case IC_INTERNAL_SERVER_ERROR:          return @"Internal Server Error";
        case IC_NOT_IMPLEMENTED:                return @"Not Implemented";
        case IC_BAD_GATEWAY:                    return @"Bad Gateway";
        case IC_SERVICE_UNAVAILABLE:            return @"Service Unavailable";
        case IC_GATEWAY_TIMEOUT:                return @"Gateway Timeout";
        case IC_PROXYING_NOT_SUPPORTED:         return @"Proxying Not Supported";
        default:                                return [NSString stringWithFormat:@"Unknown: %i", self.code];
    }
}

@end

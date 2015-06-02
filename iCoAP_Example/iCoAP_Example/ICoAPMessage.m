//
//  ICoAPMessage.m
//  iCoAP
//
//  Created by Wojtek Kordylewski on 18.06.13.

#import "ICoAPMessage.h"
#import "NSString+hex.h"

@implementation ICoAPMessage

#pragma mark - Init

- (id)init {
    if (self = [super init]) {
        self.optionDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        NSString *hexString = [NSString stringFromDataWithHex:data];
        
        //Check if header exists:
        if ([hexString length] < 8) {
            return nil;
        }
        
        self.isRequest = NO;
        self.type = (uint)strtol([[hexString substringWithRange:NSMakeRange(0, 1)] UTF8String], NULL, 16);                // Message Type
        uint tokenLength = (uint)strtol([[hexString substringWithRange:NSMakeRange(1, 1)] UTF8String], NULL, 16);               // Token length (In Bytes)
        self.token = (uint)strtol([[hexString substringWithRange:NSMakeRange(8, tokenLength * 2)] UTF8String], NULL, 16); // Token
        self.code = (uint)strtol([[hexString substringWithRange:NSMakeRange(2, 2)] UTF8String], NULL, 16);                // Code
        self.messageID = (uint)strtol([[hexString substringWithRange:NSMakeRange(4, 4)] UTF8String], NULL, 16);           // Message ID
        
        //Options && Payload
        int optionIndex = 8 + (tokenLength * 2);
        int payloadStartIndex = optionIndex;
        uint prevOptionDelta = 0;
        
        
        //Check if Options and More exists
        BOOL isOptionLoopRunning = YES;
        
        while (isOptionLoopRunning) {
            if (optionIndex + 2 < [hexString length]) {
                uint optionDelta = (uint)strtol([[hexString substringWithRange:NSMakeRange(optionIndex, 1)] UTF8String], NULL, 16);
                uint optionLength = (uint)strtol([[hexString substringWithRange:NSMakeRange(optionIndex + 1, 1)] UTF8String], NULL, 16);
                
                if (optionDelta == kOptionDeltaPayloadIndicator) {
                    //Payload should follow instead of Option_length. Verifying...
                    if (optionLength != kOptionDeltaPayloadIndicator) {
                        return nil;
                    }
                    isOptionLoopRunning = NO;
                    payloadStartIndex = optionIndex;
                    continue;
                }
                
                uint extendedDelta = 0;
                int optionIndexOffset = 2; //marks the range between the beginning of the initial option byte and the end of the 'option delta' plus 'option lenght' extended bytes in hex steps (2 = 1 byte)
                
                if (optionDelta == k8bitIntForOption) {
                    optionIndexOffset += 2;
                }
                else if (optionDelta == k16bitIntForOption) {
                    optionIndexOffset += 4;
                }
                
                if (optionIndex + optionIndexOffset <= [hexString length]) {
                    extendedDelta = (uint)strtol([[hexString substringWithRange:NSMakeRange(optionIndex + 2, optionIndexOffset - 2)] UTF8String], NULL, 16);
                }
                else {
                    return nil;
                }
                
                //Verify Length
                int optionLengthExtendedOffsetIndex = optionIndexOffset;
                if (optionLength == k8bitIntForOption) {
                    optionIndexOffset += 2;
                }
                else if (optionLength == k16bitIntForOption) {
                    optionIndexOffset += 4;
                }
                else if (optionLength == kOptionDeltaPayloadIndicator) {
                    return nil;
                }
                optionLength += strtol([[hexString substringWithRange:NSMakeRange(optionIndex + optionLengthExtendedOffsetIndex , optionIndexOffset - optionLengthExtendedOffsetIndex)] UTF8String], NULL, 16);
                
                
                if (optionIndex + optionIndexOffset + optionLength * 2 > [hexString length]) {
                    return nil;
                }
                
                uint newOptionNumber = optionDelta + extendedDelta + prevOptionDelta;
                NSString *optVal;
                
                if (newOptionNumber == IC_ETAG || newOptionNumber == IC_IF_MATCH) {
                    optVal = [hexString substringWithRange:NSMakeRange(optionIndex + optionIndexOffset, optionLength * 2)];
                }
                else if (newOptionNumber == IC_BLOCK2 || newOptionNumber == IC_URI_PORT || newOptionNumber == IC_CONTENT_FORMAT || newOptionNumber == IC_MAX_AGE || newOptionNumber == IC_ACCEPT || newOptionNumber == IC_SIZE1 || newOptionNumber == IC_SIZE2 || newOptionNumber == IC_OBSERVE) {
                    optVal = [NSString stringWithFormat:@"%i", (int)strtol([[hexString substringWithRange:NSMakeRange(optionIndex + optionIndexOffset, optionLength * 2)] UTF8String], NULL, 16)];
                }
                else {
                    optVal = [NSString stringFromHexString:[[hexString substringWithRange:NSMakeRange(optionIndex + optionIndexOffset, optionLength * 2)] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                }
                
                [self addOption:newOptionNumber withValue:optVal];
                
                prevOptionDelta += optionDelta + extendedDelta;
                optionIndex += optionIndexOffset + optionLength * 2;
            }
            else {
                isOptionLoopRunning = NO;
                payloadStartIndex = optionIndex;
            }
        }
        
        //Payload, first check if payloadmarker exists
        if (payloadStartIndex + 2 < [hexString length]) {
            self.payload = [self requiresPayloadStringDecode] ? [[NSString stringFromHexString:[hexString substringFromIndex:payloadStartIndex + 2]] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : [hexString substringFromIndex:payloadStartIndex + 2];
        }
    }
    return self;
}

- (id)initAsRequestConfirmable:(BOOL)con requestMethod:(uint)req sendToken:(BOOL)token payload:(NSString *)payload {
    if (self = [self init]) {
        if (con) {
            self.type = IC_CONFIRMABLE;
        }
        else {
            self.type = IC_NON_CONFIRMABLE;
        }
        if (req < 32) {
            self.code = req;
        }
        else {
            self.code = IC_GET;
        }
        
        self.isRequest = YES;
        self.isTokenRequested = token;
        self.payload = payload;
    }
    return self;
}

#pragma mark - Public

- (NSData *)data {
    NSMutableString *final = [[NSMutableString alloc] init];
    NSString *tokenAsString = [NSString get0To4ByteHexStringFromInt:self.token];
    
    [final appendString: [NSString stringWithFormat:@"%01X%01X%02X%04X%@", self.type, (uint)([tokenAsString length] / 2), self.code, self.messageID, tokenAsString]];
    
    NSArray *sortedArray;
    sortedArray = [[self.optionDict allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        return [a integerValue] > [b integerValue];
    }];
    
    uint previousDelta = 0;
    
    for (NSString* key in sortedArray) {
        NSMutableArray *valueArray = [self.optionDict valueForKey:key];
        
        for (uint i = 0; i < [valueArray count]; i++) {
            uint delta = [key intValue] - previousDelta;
            NSString *valueForKey;
            
            if ([key intValue] == IC_ETAG || [key intValue] == IC_IF_MATCH) {
                valueForKey = [valueArray objectAtIndex:i];
            }
            else if ([key intValue] == IC_BLOCK2 || [key intValue] == IC_URI_PORT || [key intValue] == IC_CONTENT_FORMAT || [key intValue] == IC_MAX_AGE || [key intValue] == IC_ACCEPT || [key intValue] == IC_SIZE1 || [key intValue] == IC_SIZE2) {
                valueForKey = [NSString get0To4ByteHexStringFromInt:[[valueArray objectAtIndex:i] intValue]];
            }
            else {
                valueForKey = [NSString hexStringFromString:[valueArray objectAtIndex:i]];
            }
            
            uint length = (uint)[valueForKey length] / 2;
            
            NSString *extendedDelta = @"";
            NSString *extendedLength = @"";
            
            if (delta >= 269) {
                [final appendString:[NSString stringWithFormat:@"%01X", 14]];
                extendedDelta = [NSString stringWithFormat:@"%04X", delta - 269];
            }
            else if (delta >= 13) {
                [final appendString:[NSString stringWithFormat:@"%01X", 13]];
                extendedDelta = [NSString stringWithFormat:@"%02X", delta - 13];
            }
            else {
                [final appendString:[NSString stringWithFormat:@"%01X", delta]];
            }
            
            if (length >= 269) {
                [final appendString:[NSString stringWithFormat:@"%01X", 14]];
                extendedLength = [NSString stringWithFormat:@"%04X", length - 269];
            }
            else if (length >= 13) {
                [final appendString:[NSString stringWithFormat:@"%01X", 13]];
                extendedLength = [NSString stringWithFormat:@"%02X", length - 13];
            }
            else {
                [final appendString:[NSString stringWithFormat:@"%01X", length]];
            }
            
            [final appendString:extendedDelta];
            [final appendString:extendedLength];
            [final appendString:valueForKey];
            
            previousDelta += delta;
        }
        
    }
    
    //Payload encoded to UTF-8
    if ([self.payload length] > 0) {
        if ([self requiresPayloadStringDecode]) {
            [final appendString:[NSString stringWithFormat:@"%02X%@", 255, [NSString hexStringFromString:self.payload]]];
        }
        else {
            [final appendString:[NSString stringWithFormat:@"%02X%@", 255, self.payload]];
        }
    }
    
    return [final stringToHexData];
}

#pragma mark - Message Options

- (void)addOption:(uint)option withValue:(NSString *)value {
    NSMutableArray *valueArray;
    
    if ([self.optionDict valueForKey:[NSString stringWithFormat:@"%i", option]]) {
        valueArray = [self.optionDict valueForKey:[NSString stringWithFormat:@"%i", option]];
    }
    else {
        valueArray = [[NSMutableArray alloc] init];
        [self.optionDict setValue:valueArray forKey:[NSString stringWithFormat:@"%i", option]];
    }
    
    [valueArray addObject:value];
}

- (BOOL)requiresPayloadStringDecode {
    if (![self.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_CONTENT_FORMAT]]) {
        return YES;
    }
    else if ([self.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_CONTENT_FORMAT]]) {
        NSMutableArray *values = [self.optionDict valueForKey:[NSString stringWithFormat:@"%i", IC_CONTENT_FORMAT]];
        if ([[values objectAtIndex:0] intValue] == IC_PLAIN || [[values objectAtIndex:0] intValue] == IC_LINK_FORMAT || [[values objectAtIndex:0] intValue] == IC_XML || [[values objectAtIndex:0] intValue] == IC_JSON) {
            return YES;
        }
    }
    return NO;
}

@end

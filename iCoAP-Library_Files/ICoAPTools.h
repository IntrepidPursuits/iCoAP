//
//  ICoAPTools.h
//  iCoAP_Example
//
//  Created by Maximilian Schenk on 10.03.15.
//  Copyright (c) 2015 croX Interactive. All rights reserved.
//

#import <Foundation/Foundation.h>


@class ICoAPMessage;
@interface ICoAPTools : NSObject

#pragma mark - Display Helper

+ (NSString *)getOptionDisplayStringForCoAPOptionDelta:(uint)delta;
+ (NSString *)getTypeDisplayStringForCoAPObject:(ICoAPMessage *)cO;
+ (NSString *)getCodeDisplayStringForCoAPObject:(ICoAPMessage *)cO;

@end

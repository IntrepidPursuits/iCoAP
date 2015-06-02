//
//  ICoAPMessage+DisplayHelper.h
//  iCoAP_Example
//
//  Created by Patrick Butkiewicz on 6/2/15.
//  Copyright (c) 2015 croX Interactive. All rights reserved.
//

#import "ICoAPMessage.h"

@interface ICoAPMessage (DisplayHelper)

- (NSString *)typeDisplayString;
- (NSString *)codeDisplayString;
+ (NSString *)optionDisplayStringFromOptionDelta:(uint)delta;

@end

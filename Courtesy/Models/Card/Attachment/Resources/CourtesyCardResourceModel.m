//
//  CourtesyCardResourceModel.m
//  Courtesy
//
//  Created by Zheng on 4/21/16.
//  Copyright © 2016 82Flex. All rights reserved.
//

#import "CourtesyCardResourceModel.h"

@implementation CourtesyCardResourceModel

+ (BOOL)propertyIsOptional:(NSString *)propertyName {
    if ([propertyName isEqualToString:@"size"]) {
        return YES;
    }
    return NO;
}

@end

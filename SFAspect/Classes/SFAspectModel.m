//
//  SFAspectModel.m
//  SFAOPDemo
//
//  Created by samstring on 2020/6/3.
//  Copyright © 2020 samstring. All rights reserved.
//

#import "SFAspectModel.h"

@implementation SFAspectModel
-(void)stop{
    [self stopWithError:nil withBlock:nil];
}

- (void)stopWithBlock:(SFStopBlock)stopBlock{
    [self stopWithError:nil withBlock:stopBlock];
}


- (void)stopWithError:(NSError *)error withBlock:(SFStopBlock)stopBlock{
    if (stopBlock) {
        stopBlock();
    }
    if (error) {
        @throw error;
    }
    NSMutableDictionary *userInfo  = [NSMutableDictionary dictionary];
    NSString *target = [NSString stringWithFormat:@"  %@  ",self.target];
    if ([target containsString:@"_sf_SubClass_"]) {
        target  = [NSString stringWithFormat:@"  %@  ",NSStringFromClass([(NSObject *)self.target superclass])];
    }
    
    [userInfo setObject:target forKey:@"target"];
    
//    [userInfo setObject:[NSString stringWithFormat:@"  %@  ",self.originalInvocation] forKey:@"originalInvocation"];
    [userInfo setObject:[NSString stringWithFormat:@"  %d  ",self.priority] forKey:@"priority"];
    [userInfo setObject:[NSString stringWithFormat:@"  %@  ",NSStringFromSelector(self.sel)] forKey:@"sel"];

     @throw [NSError errorWithDomain:@"停止往下执行" code:DefaulErrorCode userInfo:userInfo];
}
@end

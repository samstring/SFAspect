//
//  SFAspectModel.h
//  SFAOPDemo
//
//  Created by samstring on 2020/6/3.
//  Copyright © 2020 samstring. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFAspectModel : NSObject

/// 被hook的对象
@property (nonatomic, weak) id target;

/// 被hook对象的原invocation
@property (nonatomic, weak) NSInvocation *originalInvocation;

/// 切点的优先级
@property (nonatomic, assign) int priority;

/// 切点所hook的方法
@property (nonatomic, assign) SEL sel;

/// 切点的block地址
@property (nonatomic, assign) IMP imp;

/// 切点的ID
@property (nonatomic, strong) NSString *identify;
@end

NS_ASSUME_NONNULL_END

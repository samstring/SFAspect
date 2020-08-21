//
//  SFAspectModel.h
//  SFAOPDemo
//
//  Created by samstring on 2020/6/3.
//  Copyright © 2020 samstring. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DefaulErrorCode 500

typedef void(^SFStopBlock)(void);

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

///停止后续操作
-(void)stop;

/// 停止后续操作，并自定义error
/// @param stopBlock  回调
-(void)stopWithBlock:(SFStopBlock)stopBlock;

/// 停止后续操作，并自定义error
/// @param error 自定义error
/// @param stopBlock  回调
- (void)stopWithError:( NSError *)error withBlock:(SFStopBlock)stopBlock;

@end



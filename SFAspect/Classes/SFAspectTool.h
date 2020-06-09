//
//  SFAspectTool.h
//  SFAOPDemo
//
//  Created by samstring on 2020/6/1.
//  Copyright © 2020 samstring. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFAspectModel.h"
#pragma mark - 状态
typedef NS_ENUM(NSUInteger, HookOption) {
    HookOptionPre,//方法执行前
    HookOptionAfter,//方法执行后
    HookOptionInstead,//替换方法
    HookOptionAround,//围绕方法
};//hook的选项，

typedef NS_ENUM(NSUInteger, HookState) {
    HookStatePre,
    HookStateAfter,
    HookStateInstead,
};//方法执行的状态



typedef void(^HookBLock)(SFAspectModel *aspectModel,HookState state);

#pragma mark - 方法定义
@interface NSObject(SFAspectTool)

/// hook类某个对象的方法
/// @param sel 被hook的方法
/// @param identify  hook id。用于标记一个hook action，在sel 和 option相同的情况下，identify必须不同
/// @param priority  hook 的优先级，优先级越高，执行顺序越靠前
/// @param option hook 的选项
/// @param block hook回调的block
-(BOOL)hookSel:(SEL)sel withIdentify:(NSString *)identify withPriority:(int)priority withHookOption:(HookOption)option withBlock:(HookBLock)block;


/// hook类所有对象的方法
/// @param sel 被hook的方法
/// @param identify  hook id。用于标记一个hook action，在sel 和 option相同的情况下，identify必须不同
/// @param priority  hook 的优先级，优先级越高，执行顺序越靠前
/// @param option hook 的选项
/// @param block hook回调的block
+(BOOL)hookAllClassSel:(SEL)sel withIdentify:(NSString *)identify withPriority:(int)priority withHookOption:(HookOption)option withBlock:(HookBLock)block;

/// 根据 sel,identify,option去移除一个hook action。sel,identify,option可以标志唯一一个hook action
/// @param sel 被hook的方法
/// @param identify  hook id。用于标记一个hook action，在sel 和 option相同的情况下，identify必须不同
/// @param option hook 的选项
-(BOOL)removeHook:(SEL)sel withIdentify:(NSString *)identify withHookOption:(HookOption)option;


@end



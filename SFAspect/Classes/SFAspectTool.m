//
//  SFAspectTool.m
//  SFAOPDemo
//
//  Created by samstring on 2020/6/1.
//  Copyright © 2020 samstring. All rights reserved.
//设计思想，
//1将hook的函数封装成对象，再关联的对应的类或元类
//2替换被调用的方法为_objc_msgForward，让被调用的方法走消息转发。对于
//3替换掉默认的methodforsigture 和 forwarinvocation
//4在自己的forwarinvocation中查找类或是元类的hook对象。调用hook对象的函数的block;
//5对于上述步骤。如果是调用hookSel方法的话，会去动态生成一个子类，然后在子类替换被hook的方法，替换methodforsigture和forwarinvocation。如果调用的是hookAllClasSel的话，是在原类上操作
//6删除hook action的时候，在第一步关联的类或元类对象中，找到对应的hook action并删除。如果关联对象中

#import "SFAspectTool.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread/pthread.h>

#define SubClassPrefix @"_sf_SubClass_"
#define OriginalMethodPrefix @"_originalMethodPrefix_"
typedef BOOL (^LockBlock)(void);

#pragma mark - 子类对象
@interface SubClassModel : NSObject
/// 原类生成的子类
@property (nonatomic, weak) Class subClass;
/// 原类生成的子类所对应的对象
@property (nonatomic, weak) id object;
@end

#pragma mark -hook容器
@interface SFAspectContainer : NSObject

/// 被hook的方法列表
@property (nonatomic, strong) NSMutableArray<NSString *> *hookMethodArray;

/// 被hook方法前执行的action
@property (nonatomic, strong) NSMutableArray<SFAspectModel *> *preArray;
/// 被hook方法后执行的action
@property (nonatomic, strong) NSMutableArray<SFAspectModel *> *afterArray;
/// 被hook方法的替换action
@property (nonatomic, strong) NSMutableArray<SFAspectModel *> *insteadArray;
/// 被hook方法前后执行的action
@property (nonatomic, strong) NSMutableArray<SFAspectModel *> *arroundArray;

/// 被hook方法以及对应的方法描述
@property (nonatomic, strong) NSMutableDictionary<NSString *,NSString *> *methodSig;
@end

@implementation SubClassModel
@end

@implementation SFAspectContainer
-(NSMutableArray<NSString *> *)hookMethodArray{
    if (!_hookMethodArray) {
        _hookMethodArray = [NSMutableArray array];
    }
    return _hookMethodArray;
}
-(NSMutableArray<SFAspectModel *> *)preArray{
    if (!_preArray) {
        _preArray = [NSMutableArray array];
    }
    return _preArray;
}

-(NSMutableArray<SFAspectModel *> *)afterArray{
    if (!_afterArray) {
        _afterArray = [NSMutableArray array];
    }
    return _afterArray;
}

-(NSMutableArray<SFAspectModel *> *)arroundArray{
    if (!_arroundArray) {
        _arroundArray = [NSMutableArray array];
    }
    return _arroundArray;
}

- (NSMutableArray<SFAspectModel *> *)insteadArray{
    if (!_insteadArray) {
        _insteadArray = [NSMutableArray array];
    }
    return _insteadArray;
}

-(NSMutableDictionary<NSString *,NSString *> *)methodSig{
    if (!_methodSig) {
        _methodSig = [NSMutableDictionary dictionary];
    }
    return _methodSig;
}
@end

#pragma mark - 实现
@implementation NSObject(SFAspectTool)

+(void)load{
    static NSSet *disallowedSelectorList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:@"retain", @"release", @"autorelease", @"forwardInvocation:", nil];
    });
}

/// 为对象添加一个hook action
/// @param sel <#sel description#>
/// @param identify <#identify description#>
/// @param priority <#priority description#>
/// @param option <#option description#>
/// @param block <#block description#>
-(BOOL)hookSel:(SEL)sel withIdentify:(NSString *)identify withPriority:(int)priority withHookOption:(HookOption)option withBlock:(HookBLock)block{
    //动态构建一个字类，将当前的对象的类指向字类
    return  lockHookAction(^{
#pragma mark 处理类关系
        //清除元类无用的子类
        clearNoUseSubClass(self);
        //生成子类并把对象的类设置为子类
        Class subClass = generateSubClass(self,[NSString stringWithFormat:@"%p",self]);
        if (!object_isClass(self)) {
            //将当前对象的实现指向子类
            object_setClass(self, subClass);
        }
        //把动态构建的子类添加到原类的子类列表当中。
        addToOrginalSubClass(self);
#pragma mark 处理方法
        //判断方法是否名称是否已经被改名了，如果没有，则改名并去除原来的方法，并关联方法的编码
        //如果方法名称已经改名了,则把
        //如果存在，则把方法签名存起来
        
        SEL orginalSel = NSSelectorFromString([NSString stringWithFormat:@"%@%@",OriginalMethodPrefix,NSStringFromSelector(sel)]);
        
        BOOL isClassMethod  = NO;
        Method method = class_getInstanceMethod([self class], orginalSel);
        if (method == nil) {
            method = class_getClassMethod([self class], orginalSel);
            if (method) {
                isClassMethod = YES;
            }
        }
        
        if (method == nil ||  class_getMethodImplementation([self class], sel) == aspect_getMsgForwardIMP([self class], sel) ) {
            //判断hook的方法在是否在原类中存在
            BOOL isForward = NO;
            if ( method_getImplementation(class_getInstanceMethod([self class], sel)) == aspect_getMsgForwardIMP([self class], sel)) {
                isForward = YES;
            }
            if (isForward == NO && method_getImplementation(class_getInstanceMethod(objc_getMetaClass(object_getClassName([self class])), sel)) == aspect_getMsgForwardIMP([self class], sel)) {
                isForward = YES;
            }
            
            if ( !isForward ) {
                method = class_getInstanceMethod([self class], sel);
                if(method == nil){
                    method = class_getClassMethod([self class], sel);
                    if (method) {
                        isClassMethod = YES;
                    }
                    
                }
            }else{
                //如果元类的方法被hook过，则method 等于 orginalSel的实现
                method = class_getInstanceMethod([self class], orginalSel);
                if(method == nil){
                    method = class_getClassMethod([self class], orginalSel);
                    if (method) {
                        isClassMethod = YES;
                    }
                    
                }
            }
        }
        
        //如果方法存在，则hook
        if (method == nil) {
            NSLog(@"你想hook的方法不存在");
            return NO;
        }
        else{
            //                id method_object = self;
            const char *methodTypeCode = method_getTypeEncoding(method);
            
            
            if (isClassMethod) {
                //                               if (object_isClass(self)) {
                
                Class metaClass = objc_getMetaClass(class_getName([self class]));
                SFAspectContainer *container =getHookActionContainer(metaClass);
                //关联方法编码，以供methodSignatureForSelector使用
                [container.methodSig setObject:[NSString stringWithUTF8String:methodTypeCode] forKey:NSStringFromSelector(sel)];
                class_addMethod(metaClass, orginalSel, method_getImplementation(method), methodTypeCode);
                class_replaceMethod(metaClass, sel, aspect_getMsgForwardIMP(metaClass, sel), methodTypeCode);
                //替换签名
                Method methodSig = class_getInstanceMethod(metaClass, @selector(sf_methodSignatureForSelector:));
                class_addMethod(metaClass, selWithPrefix(OriginalMethodPrefix, @selector(methodSignatureForSelector:)),method_getImplementation(class_getInstanceMethod(metaClass, @selector(methodSignatureForSelector:))),method_getTypeEncoding(methodSig));
                class_replaceMethod(metaClass, @selector(methodSignatureForSelector:), method_getImplementation(methodSig), method_getTypeEncoding(methodSig));
                
                //替换forwardInvocation
                Method methodForWard = class_getInstanceMethod(metaClass, @selector(sf_forwardInvocation:));
                class_addMethod(metaClass, selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)), method_getImplementation(methodForWard), methodTypeCode);
                class_replaceMethod(metaClass, @selector(forwardInvocation:), method_getImplementation(methodForWard), method_getTypeEncoding(methodForWard));
                [container.methodSig setObject:[NSString stringWithUTF8String:method_getTypeEncoding(methodForWard)] forKey:NSStringFromSelector(selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)))];
                [getHookActionContainer(metaClass).hookMethodArray addObject:NSStringFromSelector(sel)];
                
            }else{
                SFAspectContainer *container =getHookActionContainer([self class]);
                [container.methodSig setObject:[NSString stringWithUTF8String:methodTypeCode] forKey:NSStringFromSelector(sel)];
                class_addMethod([self class], orginalSel, method_getImplementation(method), methodTypeCode);
                class_replaceMethod([self class], sel, aspect_getMsgForwardIMP([self class], sel), methodTypeCode);
                
                Method methodSig = class_getInstanceMethod([self class], @selector(sf_methodSignatureForSelector:));
                class_addMethod([self class], selWithPrefix(OriginalMethodPrefix, @selector(methodSignatureForSelector:)),method_getImplementation(class_getInstanceMethod([self class], @selector(methodSignatureForSelector:))),method_getTypeEncoding(methodSig));
                class_replaceMethod([self class], @selector(methodSignatureForSelector:), method_getImplementation(methodSig), method_getTypeEncoding(methodSig));
                
                //替换forwardInvocation
                Method methodForWard = class_getInstanceMethod([self class], @selector(sf_forwardInvocation:));
                
                class_addMethod([self class], selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)), method_getImplementation(methodForWard), methodTypeCode);
                class_replaceMethod([self class], @selector(forwardInvocation:), method_getImplementation(methodForWard), method_getTypeEncoding(methodForWard));
                [container.methodSig setObject:[NSString stringWithUTF8String:method_getTypeEncoding(methodForWard)] forKey:NSStringFromSelector(selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)))];
                [getHookActionContainer([self class]).hookMethodArray addObject:NSStringFromSelector(sel)];
            }
        }
        
        
        
        
        
        
        
        if (isClassMethod) {
            return addHookAction(sel, identify, priority, option, block, objc_getMetaClass(object_getClassName([self class])));
        }else{
            return addHookAction(sel, identify, priority, option, block, [self class]);
        }
        
        return YES;
    });
    
}


/// 为类的所有对象添加一个hook action
/// @param sel <#sel description#>
/// @param identify <#identify description#>
/// @param priority <#priority description#>
/// @param option <#option description#>
/// @param block <#block description#>
+(BOOL)hookAllClassSel:(SEL)sel withIdentify:(NSString *)identify withPriority:(int)priority withHookOption:(HookOption)option withBlock:(HookBLock)block{
    return lockHookAction(^{
        BOOL isClassMethod  = NO;
        SEL orginalSel = NSSelectorFromString([NSString stringWithFormat:@"%@%@",OriginalMethodPrefix,NSStringFromSelector(sel)]);
        
        Method method = class_getInstanceMethod([self class], orginalSel);
        if (method == nil) {
            method = class_getClassMethod([self class], orginalSel);
            if (method) {
                isClassMethod = YES;
            }
        }
        
        
        if (method == nil) {
            //判断hook的方法在是否在类中存在
            method = class_getInstanceMethod([self class], sel);
            if(method == nil){
                method = class_getClassMethod([self class], sel);
                if (method) {
                    isClassMethod = YES;
                }
            }
        }
        if (method == nil) {
            NSLog(@"你想hook的方法不存在");
            return NO;
        }
        else{
            //                id method_object = self;
            const char *methodTypeCode = method_getTypeEncoding(method);
            
            //接下来要移除原有的方法实现
            if (isClassMethod) {
                //                               if (object_isClass(self)) {
                Class metaClass = objc_getMetaClass(class_getName([self class]));
                SFAspectContainer *container =getHookActionContainer(metaClass);
                //关联方法编码，以供methodSignatureForSelector使用
                [container.methodSig setObject:[NSString stringWithUTF8String:methodTypeCode] forKey:NSStringFromSelector(sel)];
                class_addMethod(metaClass, orginalSel, method_getImplementation(method), methodTypeCode);
                class_replaceMethod(metaClass, sel, aspect_getMsgForwardIMP(metaClass, sel), methodTypeCode);
                
                Method methodSig = class_getInstanceMethod(metaClass, @selector(sf_methodSignatureForSelector:));
                class_addMethod(metaClass, selWithPrefix(OriginalMethodPrefix, @selector(methodSignatureForSelector:)),method_getImplementation(class_getInstanceMethod([self class], @selector(methodSignatureForSelector:))),method_getTypeEncoding(methodSig));
                class_replaceMethod(metaClass, @selector(methodSignatureForSelector:), method_getImplementation(methodSig), method_getTypeEncoding(methodSig));
                
                //替换forwardInvocation
                Method methodForWard = class_getInstanceMethod(metaClass, @selector(sf_forwardInvocation:));
                class_addMethod(metaClass, selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)),method_getImplementation(class_getInstanceMethod(metaClass, @selector(forwardInvocation:))),method_getTypeEncoding(methodForWard));
                class_replaceMethod(metaClass, @selector(forwardInvocation:), method_getImplementation(methodForWard), method_getTypeEncoding(methodForWard));
                //添加hook方法
                [container.methodSig setObject:[NSString stringWithUTF8String:method_getTypeEncoding(methodForWard)] forKey:NSStringFromSelector(selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)))];
                [getHookActionContainer(metaClass).hookMethodArray addObject:NSStringFromSelector(sel)];
            }else{
                SFAspectContainer *container =getHookActionContainer([self class]);
                [container.methodSig setObject:[NSString stringWithUTF8String:methodTypeCode] forKey:NSStringFromSelector(sel)];
                //替换beihook方法
                class_addMethod([self class], orginalSel, method_getImplementation(method), methodTypeCode);
                class_replaceMethod([self class], sel, aspect_getMsgForwardIMP([self class], sel), methodTypeCode);
                //替换签名
                Method methodSig = class_getInstanceMethod([self class], @selector(sf_methodSignatureForSelector:));
                class_addMethod([self class], selWithPrefix(OriginalMethodPrefix, @selector(methodSignatureForSelector:)),method_getImplementation(class_getInstanceMethod([self class], @selector(methodSignatureForSelector:))),method_getTypeEncoding(methodSig));
                class_replaceMethod([self class], @selector(methodSignatureForSelector:), method_getImplementation(methodSig), method_getTypeEncoding(methodSig));
                
                //替换forwardInvocation
                Method methodForWard = class_getInstanceMethod([self class], @selector(sf_forwardInvocation:));
                class_addMethod([self class], selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)),method_getImplementation(class_getInstanceMethod([self class], @selector(forwardInvocation:))),method_getTypeEncoding(methodForWard));
                class_replaceMethod([self class], @selector(forwardInvocation:), method_getImplementation(methodForWard), method_getTypeEncoding(methodForWard));
                [container.methodSig setObject:[NSString stringWithUTF8String:method_getTypeEncoding(methodForWard)] forKey:NSStringFromSelector(selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)))];
                
                [getHookActionContainer([self class]).hookMethodArray addObject:NSStringFromSelector(sel)];
            }
            
            
            
        }
        
        
        
        
        if (isClassMethod) {
            return addHookAction(sel, identify, priority, option, block, objc_getMetaClass(class_getName([self class])));
        }else{
            return addHookAction(sel, identify, priority, option, block, [self class]);
        }
        return YES;
        
    });
}


-(void)removeHookInSFAspectBlock:(SEL)sel withIdentify:(NSString *)identify withHookOption:(HookOption)option{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeHook:sel withIdentify:identify withHookOption:option];
    });
}

/// 删除一个hook action
/// @param sel <#sel description#>
/// @param identify <#identify description#>
/// @param option <#option description#>
-(BOOL)removeHook:(SEL)sel withIdentify:(NSString *)identify withHookOption:(HookOption)option{
    return lockHookAction(^{
#pragma mark //清除hook action
        BOOL isClassMethod = NO;
        SFAspectContainer *container =  getHookActionContainer([self class]);
        if (![container.hookMethodArray containsObject:NSStringFromSelector(sel)]) {
            container = getHookActionContainer(objc_getMetaClass(class_getName([self class])));
            if (![container.hookMethodArray containsObject:NSStringFromSelector(sel)]) {
                NSLog(@"%@没有被hook过",NSStringFromSelector(sel));
                return  NO;
            }
            isClassMethod = YES;
            
        }
        NSMutableArray<SFAspectModel *> *hookArray = nil;
        switch (option) {
            case HookOptionPre:
            {
                hookArray = container.preArray;
            }
                break;
            case HookOptionAfter:
            {
                hookArray = container.afterArray;
            }
                break;
            case HookOptionAround:
            {
                hookArray = container.arroundArray;
            }
                break;
            case HookOptionInstead:
            {
                hookArray = container.insteadArray;
            }
                break;
                
            default:
                break;
        }
        
        if (hookArray == nil) {
            //               return  NO;
        }
        for (int i = 0; i < hookArray.count; i++) {
            if ([hookArray[i].identify isEqualToString:identify] && hookArray[i].sel == sel) {
                [hookArray removeObjectAtIndex:i];
                break;
                //                   return YES;
            }
        }
        
        
#pragma mark //如果hook数组里面内容为空，则代表没有hook，没有hook的情况下重置类或重置方法
        if(container.preArray.count == 0 && container.afterArray.count == 0 && container.insteadArray.count == 0 && container.arroundArray.count == 0){
            //判断是否是子类
            if([NSStringFromClass([self class]) hasPrefix:SubClassPrefix]){
                if (!object_isClass(self)) {
                    //如果是调用者是对象，且不存在任何hook方法，则删除类
                    //如果调用者不是对象，只能等下一次hook的时候才能清除对象
                    if(isClassMethod)
                    {
                        //如果符合上面条件的是类方法，则检测对象方法是否有被hook，没有hook的情况下删除类
                        SFAspectContainer *classcontainer = getHookActionContainer([self class]);
                        if(classcontainer.preArray.count == 0 && classcontainer.afterArray.count == 0 && classcontainer.insteadArray.count == 0 && classcontainer.arroundArray.count == 0){
                            //清除父类中的关联对象
                            NSMutableArray<SubClassModel *> *array =  objc_getAssociatedObject([self superclass], "subClassArray");
                            for (int i = 0; i < array.count; i++) {
                                SubClassModel *subClass = array[i];
                                if (subClass.subClass == [self class]) {
                                    [array removeObject:subClass];
                                    break;
                                }
                            }
                            
                            Class class = [self class];
                            object_setClass(self, [self superclass]);
                            objc_disposeClassPair(class);
                        }
                    }else{
                        //如果符合上面条件的不是类方法，则检测类方法是否有被hook，没有hook的情况下删除类
                        SFAspectContainer *metaClasscontainer = getHookActionContainer(objc_getMetaClass(class_getName([self class])));
                        //                    SFAspectContainer *metaClasscontainer = getHookActionContainer([self class]);
                        if(metaClasscontainer.preArray.count == 0 && metaClasscontainer.afterArray.count == 0 && metaClasscontainer.insteadArray.count == 0 && metaClasscontainer.arroundArray.count == 0){
                            
                            //清除父类中的关联对象
                            NSMutableArray<SubClassModel *> *array =  objc_getAssociatedObject([self superclass], "subClassArray");
                            for (int i = 0; i < array.count; i++) {
                                SubClassModel *subClass = array[i];
                                if (subClass.subClass == [self class]) {
                                    [array removeObject:subClass];
                                    break;
                                }
                            }
                            
                            Class class = [self class];
                            object_setClass(self, [self superclass]);
                            objc_disposeClassPair(class);
                        }
                    }
                    
                    
                }
            }else{
                //hook原类的，则重置元类的方法
                for (int i = 0; i < container.hookMethodArray.count; i++) {
                    NSString *selString = container.hookMethodArray[i];
                    SEL orginalSel = selWithPrefix(OriginalMethodPrefix, NSSelectorFromString(selString));
                    if (!isClassMethod) {
                        //删除
                        if (class_getInstanceMethod([self class], orginalSel)) {
                            class_replaceMethod([self class], NSSelectorFromString(selString), class_getMethodImplementation([self class], orginalSel), [[container.methodSig objectForKey:selString] UTF8String]);
                        }
                    }else{
                        Class metaClass = objc_getMetaClass(class_getName([self class]));
                        if (class_getInstanceMethod(metaClass, orginalSel)) {
                            class_replaceMethod(metaClass, NSSelectorFromString(selString), class_getMethodImplementation(metaClass, orginalSel), [[container.methodSig objectForKey:selString] UTF8String]);
                        }
                    }
                }
                
                
                //重置方法签名和方法转发
                SEL methodSigSEL = @selector(methodSignatureForSelector:);
                SEL forwardSEL = @selector(forwardInvocation:);
                if(!isClassMethod){
                    if (class_getInstanceMethod([self class], selWithPrefix(OriginalMethodPrefix, methodSigSEL))) {
                        class_replaceMethod([self class], methodSigSEL,method_getImplementation(class_getInstanceMethod([self class], selWithPrefix(OriginalMethodPrefix, methodSigSEL))), [[container.methodSig objectForKey:NSStringFromSelector(methodSigSEL)] UTF8String]);
                    }
                    if (class_getInstanceMethod([self class], selWithPrefix(OriginalMethodPrefix, forwardSEL))) {
                        class_replaceMethod([self class], forwardSEL,method_getImplementation(class_getInstanceMethod([self class], selWithPrefix(OriginalMethodPrefix, forwardSEL))), [[container.methodSig objectForKey:NSStringFromSelector(forwardSEL)] UTF8String]);
                    }
                }else{
                    Class metaClass = objc_getMetaClass(class_getName([self class]));
                    if (class_getInstanceMethod(metaClass, selWithPrefix(OriginalMethodPrefix, methodSigSEL))) {
                        class_replaceMethod(metaClass, methodSigSEL,method_getImplementation(class_getInstanceMethod(metaClass, selWithPrefix(OriginalMethodPrefix, methodSigSEL))), [[container.methodSig objectForKey:NSStringFromSelector(methodSigSEL)] UTF8String]);
                    }
                    if (class_getInstanceMethod(metaClass, selWithPrefix(OriginalMethodPrefix, forwardSEL))) {
                        class_replaceMethod(metaClass, forwardSEL,method_getImplementation(class_getInstanceMethod(metaClass, selWithPrefix(OriginalMethodPrefix, forwardSEL))), [[container.methodSig objectForKey:NSStringFromSelector(forwardSEL)] UTF8String]);
                    }
                }
                //删除SFAspectContainer容器内容
                objc_setAssociatedObject([self class], "hook_action_container", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                
            }
            
            
        }
        return YES;
    });
}

#pragma mark - 消息转发处理
-(NSMethodSignature *)sf_methodSignatureForSelector:(SEL)aSelector{
    return  getMmethodSignatureForSelector([self class],aSelector);
}

+(NSMethodSignature *)sf_methodSignatureForSelector:(SEL)aSelector{
    return  getMmethodSignatureForSelector(objc_getMetaClass(class_getName([self class])),aSelector);
}


- (void)sf_forwardInvocation:(NSInvocation *)anInvocation{
    set_ForwardInvocation(self,anInvocation);
    
}

+ (void)sf_forwardInvocation:(NSInvocation *)anInvocation{
    set_ForwardInvocation([self class],anInvocation);
    
}


NSMethodSignature * getMmethodSignatureForSelector(id object,SEL aSelector){
    SFAspectContainer *container = getHookActionContainer(object);
    NSString *methodTypeCode = [container.methodSig objectForKey:NSStringFromSelector(aSelector)];
    if (!methodTypeCode) {
        SFAspectContainer *superClassContainer = getHookActionContainer([object superclass]);
        methodTypeCode = [superClassContainer.methodSig objectForKey:NSStringFromSelector(aSelector)];
        if (!methodTypeCode) {
            return nil;
        }
    }
    
    NSMethodSignature *returnSignature= [NSMethodSignature signatureWithObjCTypes:[methodTypeCode UTF8String]];
    return returnSignature;
    
}



void set_ForwardInvocation(id object,NSInvocation *anInvocation){
    
    
    SEL sel = anInvocation.selector;
    id assocationObject;
    if (!object_isClass(object)) {
        assocationObject = [object class];
    }else{
        assocationObject = objc_getMetaClass(class_getName(object));
    }
    
    SFAspectContainer *container = getHookActionContainer(assocationObject);
    NSString *methodTypeCode = [container.methodSig objectForKey:NSStringFromSelector(anInvocation.selector)];
    
    if (!methodTypeCode) {
        methodTypeCode = [container.methodSig objectForKey:NSStringFromSelector(anInvocation.selector)];
        if (!methodTypeCode) {
            SFAspectContainer *superClassContainer = getHookActionContainer([assocationObject superclass]);
            methodTypeCode = [superClassContainer.methodSig objectForKey:NSStringFromSelector(anInvocation.selector)];
            if (!methodTypeCode) {
                [object performSelector:selWithPrefix(OriginalMethodPrefix, @selector(forwardInvocation:)) withObject:anInvocation];
                return;
            }
            
        }
        
    }
    
    //获取block,并传入参数和状态
#pragma 获取pre
    NSMutableArray<SFAspectModel *> *preHookArray = [NSMutableArray array];
    [preHookArray addObjectsFromArray:getHookActionContainer(assocationObject).preArray];
    [preHookArray addObjectsFromArray:getHookActionContainer([assocationObject superclass]).preArray];
    [preHookArray addObjectsFromArray:getHookActionContainer(assocationObject).arroundArray];
    [preHookArray addObjectsFromArray:getHookActionContainer([assocationObject superclass]).arroundArray];
    
    sortActionArray(preHookArray);
    @try {
        for (int i = 0 ; i < preHookArray.count; i++) {
            __weak SFAspectModel *model = preHookArray[i];
            if (model.sel == sel) {
                HookBLock block =  imp_getBlock(preHookArray[i].imp);
                
                model.target =object;
                model.originalInvocation = anInvocation;
                if (block) {
                    block(model,HookStatePre);
                }
            }
            
        }
        
    } @catch (NSError *error) {
        //        NSException
        NSLog(@"========={%@}===========",error);
        return;
    }@catch(NSObject *objcet){
        NSLog(@"========={%@}===========",object);
        return;
    }
    @finally {
    }
    //    SFAspectModel *insteadModel = [self insteadHookModel:anInvocation.selector];
#pragma 获取instead
    NSMutableArray<SFAspectModel *> *insteadHookArray = [NSMutableArray array];
    [insteadHookArray addObjectsFromArray:getHookActionContainer(assocationObject).insteadArray];
    [insteadHookArray addObjectsFromArray:getHookActionContainer([assocationObject superclass]).insteadArray];
    sortActionArray(insteadHookArray);
    
    if (insteadHookArray.count > 0) {
        __weak SFAspectModel *insteadModel = insteadHookArray[0];
        if (insteadModel.sel == sel) {
            @try{
                insteadModel.target =object;
                HookBLock block =  imp_getBlock(insteadModel.imp);
                insteadModel.originalInvocation = anInvocation;
                if (block) {
                    block(insteadModel,HookStateInstead);
                }
            } @catch (NSError *error) {
                //        NSException
                NSLog(@"========={%@}===========",error);
                return;
            }@catch(NSObject *objcet){
                NSLog(@"========={%@}===========",object);
                return;
            }
            @finally {
            }
        }
        
    }else{
        
        anInvocation.target = object;
        SEL orginalSel = selWithPrefix(OriginalMethodPrefix, anInvocation.selector);
        anInvocation.selector = orginalSel;
        [anInvocation invoke];
    }
    
    //获取block,并传入参数和状态
    NSMutableArray<SFAspectModel *> *afterHookArray = [NSMutableArray array];
    [afterHookArray addObjectsFromArray:getHookActionContainer(assocationObject).arroundArray];
    [afterHookArray addObjectsFromArray:getHookActionContainer([assocationObject superclass]).arroundArray];
    [afterHookArray addObjectsFromArray:getHookActionContainer(assocationObject).afterArray];
    [afterHookArray addObjectsFromArray:getHookActionContainer([assocationObject superclass]).afterArray];
    
    sortActionArray(afterHookArray);
    @try{
        for (int i = 0 ; i < afterHookArray.count; i++) {
            __weak SFAspectModel *model = afterHookArray[i];
            if (model.sel == sel) {
                HookBLock block =  imp_getBlock(afterHookArray[i].imp);
                
                model.target =object;
                model.originalInvocation = anInvocation;
                if (block) {
                    block(model,HookStateAfter);
                }
            }
            
        }
    } @catch (NSError *error) {
        //        NSException
        NSLog(@"========={%@}===========",error);
        return;
    }@catch(NSObject *objcet){
        NSLog(@"========={%@}===========",object);
        return;
    }
    @finally {
    }
    
}


#pragma mark - 拼接sel

SEL selWithPrefix(NSString *prefix,SEL sel){
    return NSSelectorFromString([NSString stringWithFormat:@"%@%@",prefix,NSStringFromSelector(sel)]);
}


#pragma mark - 消息转发
/// 将消息转发替换被hook的方法，这样每次调用被hook的方法的时候都会走消息转发机制
/// @param object <#object description#>
/// @param selector <#selector description#>
static IMP aspect_getMsgForwardIMP(id object, SEL selector) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    Class selfClass  = object;
    
    Method method = class_getInstanceMethod(selfClass, selector);
    if (method == nil) {
        if (!class_isMetaClass(object)) {
            method = class_getClassMethod(objc_getMetaClass(object_getClassName(selfClass)), selector);
        }else{
            method = class_getClassMethod(selfClass, selector);
        }
        
    }
    const char *encoding = method_getTypeEncoding(method);
    if (encoding == nil) {
        return msgForwardIMP;
    }
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);
            
            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
        } @catch (__unused NSException *e) {}
    }
    if (methodReturnsStructValue) {
        msgForwardIMP = (IMP)_objc_msgForward_stret;
    }
#endif
    return msgForwardIMP;
}

#pragma mark - 关联对象

/// hook action 的容器，对象的hook关联类。类的hook关联类的元类
/// @param object <#object description#>
SFAspectContainer * getHookActionContainer(id object){
    id assocatiatedObject = object;
    SFAspectContainer *hookActionContainer = objc_getAssociatedObject(assocatiatedObject, "hook_action_container");
    if (hookActionContainer == nil) {
        //        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(assocatiatedObject, "hook_action_container", [SFAspectContainer new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        hookActionContainer = objc_getAssociatedObject(assocatiatedObject, "hook_action_container");
    }
    return hookActionContainer;
}

#pragma mark - 子类相关操作

/// 生成一个子类
/// @param object <#object description#>
/// @param identify <#identify description#>
Class generateSubClass(NSObject * object,NSString *identify){
    
    const char *subClassName;
    if([[NSString stringWithUTF8String:class_getName([object class])] hasPrefix:SubClassPrefix]){
        subClassName = [[NSString stringWithFormat:@"%s",class_getName([object class])] UTF8String];
        
    }else{
        subClassName = [[NSString stringWithFormat:@"%@%s%@",SubClassPrefix,class_getName([object class]),identify] UTF8String];
    }
    
    
    
    Class subClass = objc_getClass(subClassName);
    if (subClass == nil) {
        
        if (object_isClass(object)) {
            subClass = objc_allocateClassPair(objc_getMetaClass(class_getName([object class])), subClassName, 0);
            objc_registerClassPair(subClass);
            
        }else{
            subClass = objc_allocateClassPair([object class], subClassName, 0);
            const void *subMetaKey = "subMetaClass";
            id objectClass = [object class];
            if(objc_getAssociatedObject(objectClass, subMetaKey)){
                object_setClass(subClass, objc_getAssociatedObject(objectClass, subMetaKey));
            }
            objc_registerClassPair(subClass);
        }
        
        
    }
    
    return subClass;
}

///调用的hookSel，会清除内存中无用的子类
/// @param object <#object description#>
void clearNoUseSubClass(id object){
    NSMutableArray<SubClassModel *> *array = nil;
    if([NSStringFromClass([object class]) hasPrefix:SubClassPrefix]){
        objc_getAssociatedObject([object superclass], "subClassArray");
    }
    else{
        objc_getAssociatedObject([object class], "subClassArray");
    }
    
    if (array == nil) {
        objc_setAssociatedObject([object class], "subClassArray", [NSMutableArray array], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }else{
        for (int i = 0; i < array.count; i++) {
            SubClassModel *model = array[i];
            if (model.object == nil && model.subClass != nil ) {
                [array removeObject:model];
                objc_disposeClassPair(model.subClass);
                i = i-1;
                
            }
            
        }
        
    }
    
}

/// 如果调用的是hookSel，则会为每一个对象生成一个子类
/// @param object <#object description#>
void addToOrginalSubClass(id object){
    //原类关联子类对象数组
    NSMutableArray<SubClassModel *> *array =  objc_getAssociatedObject([object superclass], "subClassArray");
    if (array == nil) {
        array = [NSMutableArray array];
    }
    
    objc_setAssociatedObject([object superclass], "subClassArray", array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    //往数组添加元素
    BOOL isExitSubClass = NO;
    for (int i = 0; i < array.count; i++) {
        SubClassModel *subClass = array[i];
        if (subClass.subClass == [object class]) {
            isExitSubClass = YES;
            break;
        }
    }
    if (!isExitSubClass) {
        SubClassModel *subModel = [SubClassModel new];
        subModel.subClass = [object class];
        subModel.object =object;
        [array addObject:subModel];
    }
}

#pragma mark - 添加hook回调
BOOL addHookAction(SEL sel,NSString *identify,int priority,HookOption option,HookBLock block,Class aClass){
    //把block里面需要执行的内容存起来
    //2 将blockl转换成imp，然后包装成个对象，存到数组里面
    SFAspectModel *model = [SFAspectModel new];
    [block copy];
    model.imp = imp_implementationWithBlock(block);
    model.priority = priority;
    model.identify = identify;
    model.sel = sel;
    
    SFAspectContainer *container = getHookActionContainer(aClass);
    
    [container.hookMethodArray addObject:identify];
    switch (option) {
        case HookOptionPre:
        {
            for (int i = 0; i <container.preArray.count; i++) {
                if ([container.preArray[i].identify isEqualToString:identify] && container.preArray[i].sel == sel) {
                    NSLog(@"相同类型和ID的hook已存在，hook不成功");
                    return NO;
                }
            }
            [container.preArray addObject:model];
            sortActionArray(container.preArray);
        }
            break;
        case HookOptionAfter:
        {
            for (int i = 0; i <container.afterArray.count; i++) {
                if ([container.afterArray[i].identify isEqualToString:identify] && container.afterArray[i].sel == sel) {
                    NSLog(@"相同类型和ID的hook已存在，hook不成功");
                    return NO;
                }
            }
            [container.afterArray addObject:model];
            sortActionArray(container.afterArray);
        }
            break;
        case HookOptionAround:
        {
            for (int i = 0; i <container.arroundArray.count; i++) {
                if ([container.arroundArray[i].identify isEqualToString:identify] && container.arroundArray[i].sel == sel) {
                    NSLog(@"相同类型和ID的hook已存在，hook不成功");
                    return NO;
                }
            }
            [container.arroundArray addObject:model];
            sortActionArray(container.arroundArray);
        }
            break;
        case HookOptionInstead:
        {
            for (int i = 0; i <container.insteadArray.count; i++) {
                if ([container.insteadArray[i].identify isEqualToString:identify] && container.insteadArray[i].sel == sel) {
                    NSLog(@"相同类型和ID的hook已存在，hook不成功");
                    return NO;
                }
            }
            [container.insteadArray addObject:model];
            sortActionArray(container.insteadArray);
        }
            break;
            
        default:
            break;
    }
    return YES;
    
}

#pragma mark - action 根据优先级排序
void sortActionArray(NSMutableArray<SFAspectModel *> *array){
    [array sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        if(((SFAspectModel *)obj1).priority >= ((SFAspectModel *)obj2).priority ){
            return NSOrderedAscending;
        }
        //        else if(((SFAspectModel *)obj1).priority == ((SFAspectModel *)obj2).priority ){
        //            return NSOrderedSame;
        //        }
        else{
            return NSOrderedDescending;
        }
        
    }];
}


#pragma mark - 锁操作
static BOOL lockHookAction(LockBlock block) {
    static pthread_mutex_t mutex =PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&mutex);
    BOOL result = block();
    
    pthread_mutex_unlock(&mutex);
    return result;
    
}

@end



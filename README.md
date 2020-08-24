# SFAspect

[![CI Status](https://img.shields.io/travis/samstring/SFAspect.svg?style=flat)](https://travis-ci.org/samstring/SFAspect)
[![Version](https://img.shields.io/cocoapods/v/SFAspect.svg?style=flat)](https://cocoapods.org/pods/SFAspect)
[![License](https://img.shields.io/cocoapods/l/SFAspect.svg?style=flat)](https://cocoapods.org/pods/SFAspect)
[![Platform](https://img.shields.io/cocoapods/p/SFAspect.svg?style=flat)](https://cocoapods.org/pods/SFAspect)


## 安装

```ruby
pod 'SFAspect'
```

## 实现原理

[iOS中AOP面向切面编程SFAspect](https://www.jianshu.com/p/93328288ddc8)

## 使用
- hook单个对象实例方法
```
 [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        BOOL animated = NO;
        NSInvocation *invocation =  aspectModel.originalInvocation;
        //参数从2开始，因为方法执行的时候隐式携带了两个参数：self 和 _cmd，self是方法调用者，_cmd是被调用f方法的sel
        [invocation getArgument:&animated atIndex:2];
        NSLog(@"准备执行viewWillAppear,参数animated的值为%d",animated);
        //改变参数
        animated  = NO;
        [invocation setArgument:&animated atIndex:2];
    }];
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"2" withPriority:0 withHookOption:(HookOptionAfter) withBlock:^(SFAspectModel *aspectModel, HookState state) {
           BOOL animated = NO;
           NSInvocation *invocation =  aspectModel.originalInvocation;
           //参数从2开始，因为方法执行的时候隐式携带了两个参数：self 和 _cmd，self是方法调用者，_cmd是被调用f方法的sel
           [invocation getArgument:&animated atIndex:2];
           NSLog(@"执行viewWillAppear后,参数animated的值为%d",animated);
        //也可以通过invocation获取返回值，详情参考消息转发过程中NSInvocation的用法
          
       }];
```

- hook单个对象的类方法
```
 [self.vc hookSel:@selector(sayHiTo:withVCTitle:) withIdentify:@"3" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        NSLog(@"hook单个对象的类方法");
    }];
  //调用单个对象的类方法(如果直接用[ClassName sayHiTo:@"" withVCTitle:@""]这种方式不会触发hook)
  [[self.vc class] sayHiTo:@"" withVCTitle:@""];
```

- hook类的所有对象的实例方法
```
 [SFHookViewController hookAllClassSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
       BOOL animated = NO;
       NSInvocation *invocation =  aspectModel.originalInvocation;
         [invocation getArgument:&animated atIndex:2];
        NSLog(@"准备执行viewWillAppear,参数animated的值为%d",animated);
        
    }];
```
- hook类所有对象的类方法
```
 [SFHookViewController hookAllClassSel:@selector(sayHiTo:withVCTitle:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
       BOOL animated = NO;
       NSInvocation *invocation =  aspectModel.originalInvocation;
         [invocation getArgument:&animated atIndex:2];
       NSLog(@"hook所有对象的类方法");
        
    }];
```
- hook同一个方法，优先级不同,优先级越高，越先执行
```
[self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {

          NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
          
      }];
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"2" withPriority:1 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
                
        
    }];
```
- 移除hook
```
[self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {

        NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
        
    }];
    //移除hook后hook里面的block不执行
    [self.vc removeHook:@selector(viewWillAppear:) withIdentify:@"1" withHookOption:(HookOptionPre)];
```
- 在hook的block中移除hook
- 移除hook
```
[self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {

        NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
        
         //移除hook后下一次执行方法的时候该hook里面的内容不执行
    [self.vc removeHookInSFAspectBlock:@selector(viewWillAppear:) withIdentify:@"1" withHookOption:(HookOptionPre)];
        
    }];
   
```
- hook中 pre,after，around的区别
```
[self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        //pre是在方法前执行
           NSLog(@"pre-准备执行viewWillAppear");
           
       }];
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"2" withPriority:0 withHookOption:(HookOptionAfter) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        //after是在方法前执行
        NSLog(@"after-执行viewWillAppear后");
        
    }];
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"3" withPriority:0 withHookOption:(HookOptionAround) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        //around是在方法前后执行
           if(state == HookStatePre){
                 NSLog(@"around准备执行viewWillAppear");
           }
           if (state == HookStateAfter) {
                 NSLog(@"around-准备执行viewWillAppear");
           }
           
       }];
```

## Author

samstring, 1264986115@qq.com

## License

SFAspect is available under the MIT license. See the LICENSE file for more info.

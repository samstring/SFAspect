//
//  SFViewController.m
//  SFAspect
//
//  Created by samstring on 06/09/2020.
//  Copyright (c) 2020 samstring. All rights reserved.
//

#import "SFViewController.h"
#import "SFHookViewController.h"
#import <SFAspectTool.h>

@interface SFViewController ()
@property (nonatomic, strong) SFHookViewController *vc;
@property (nonatomic, strong) SFHookViewController *vc1;
@end

@implementation SFViewController

//- (void)viewWillAppear:(BOOL)animated

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Hook Demo";
    
    self.vc = [[SFHookViewController alloc] initWithNibName:@"SFHookViewController" bundle:nil];
    self.vc.title = @"Hook VC";
    self.vc1 = [[SFHookViewController alloc] initWithNibName:@"SFHookViewController" bundle:nil];
    self.vc1.title = @"Hook VC1";
	// Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)hookSingleObjectInstanceMethod:(id)sender {
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
    [self.navigationController pushViewController:self.vc animated:YES];
}

- (IBAction)hookSigleObjectForClassMethod:(id)sender {
    [self.vc hookSel:@selector(sayHiTo:withVCTitle:) withIdentify:@"3" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        NSLog(@"hook单个对象的类方法");
    }];
  
    [self.navigationController pushViewController:self.vc animated:YES];
//    执行下面的方法不会引起执行上面block内容
//    [self.navigationController pushViewController:self.vc1 animated:YES];
}
- (IBAction)hookAllObjectInstanceMethod:(id)sender {
    [SFHookViewController hookAllClassSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
       BOOL animated = NO;
       NSInvocation *invocation =  aspectModel.originalInvocation;
         [invocation getArgument:&animated atIndex:2];
        NSLog(@"准备执行viewWillAppear,参数animated的值为%d",animated);
        
    }];
     [self.navigationController pushViewController:self.vc animated:YES];
     [self.navigationController pushViewController:self.vc1 animated:YES];
}
- (IBAction)hookAllObjectClassMethod:(id)sender {
    [SFHookViewController hookAllClassSel:@selector(sayHiTo:withVCTitle:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
       BOOL animated = NO;
       NSInvocation *invocation =  aspectModel.originalInvocation;
         [invocation getArgument:&animated atIndex:2];
       NSLog(@"hook所有对象的类方法");
        
    }];
     [self.navigationController pushViewController:self.vc animated:YES];
     [self.navigationController pushViewController:self.vc1 animated:YES];
}
- (IBAction)hookSameMethodWithDifferentPriority:(id)sender {
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {

          NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
          
      }];
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"2" withPriority:1 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {
        NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
                
        
    }];
    //hook类型相同，优先级高的先执行
    //如果hook类型为HookOptionPre和HookOptionAround,相同优先级的情况下，HookOptionPre先执行
    //如果hook类型为HookOptionAfter和HookOptionAround,相同优先级的情况下，HookOptionAround先执行
     [self.navigationController pushViewController:self.vc animated:YES];
}

- (IBAction)removeHook:(id)sender {
    [self.vc hookSel:@selector(viewWillAppear:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionPre) withBlock:^(SFAspectModel *aspectModel, HookState state) {

        NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
        
    }];
    //移除hook后hook里面的block不执行
    [self.vc removeHook:@selector(viewWillAppear:) withIdentify:@"1" withHookOption:(HookOptionPre)];
    [self.navigationController pushViewController:self.vc animated:YES];
}


- (IBAction)hookOption:(id)sender {

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
   
       [self.navigationController pushViewController:self.vc animated:YES];
}


@end

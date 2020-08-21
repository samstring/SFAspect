//
//  SFHookViewController.m
//  SFAspect_Example
//
//  Created by samstring on 2020/6/9.
//  Copyright © 2020 samstring. All rights reserved.
//

#import "SFHookViewController.h"
#import <SFAspectTool.h>
@interface SFHookViewController ()

@end

@implementation SFHookViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    
//    __weak typeof(self) weakSelf = self;
//    [self hookSel:@selector(sayHiTo:withVCTitle:) withIdentify:@"1" withPriority:0 withHookOption:(HookOptionAround) withBlock:^(SFAspectModel *aspectModel, HookState state) {
//
//           if (state == HookStateAfter) {
////           [aspectModel stopwi
//               [aspectModel stopWithBlock:^{
//                   UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"停止操作" message:@"" preferredStyle:(UIAlertControllerStyleAlert)];
//                   [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:(UIAlertActionStyleDefault) handler:nil]];
//                   [weakSelf presentViewController:alert animated:YES completion:nil];
//
//                   NSLog(@"--------停止后续操作");
//               }];
//           }
//
//              NSLog(@"准备执行viewWillAppear,执行的优先级是%d",aspectModel.priority);
//
//          }];
    

    
    // Do any additional setup after loading the view from its nib.
}
- (IBAction)ClickSayHi:(id)sender {
    NSString *title =self.title;
    [[self class] sayHiTo:@"张三" withVCTitle:title];
}

+(void)sayHiTo:(NSString *)name withVCTitle:(NSString *)title{
    NSLog(@"%@向%@打招呼",title,name);
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end

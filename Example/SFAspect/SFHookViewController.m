//
//  SFHookViewController.m
//  SFAspect_Example
//
//  Created by samstring on 2020/6/9.
//  Copyright © 2020 samstring. All rights reserved.
//

#import "SFHookViewController.h"

@interface SFHookViewController ()

@end

@implementation SFHookViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
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

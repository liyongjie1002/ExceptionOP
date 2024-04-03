//
//  ViewController.m
//  ExceptionOP
//
//  Created by 李永杰 on 2024/2/22.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

/*
 添加异常捕获监听函数，只能监听NSException类型的异常
 */
- (IBAction)exceptionAction {
    NSDictionary *userInfo = [[NSDictionary alloc]initWithObjectsAndKeys:@"info1", @"key1", nil];
    NSException *exception = [[NSException alloc]initWithName:@"自定义异常" reason:@"自定义异常原因" userInfo:userInfo];
    @throw exception;
}
/* 而引起崩溃的大多数原因如：内存访问错误，重复释放等错误就无能为力了。因为这种错误它抛出的是Signal，所以必须要专门做Signal处理, 可以参考如下封装；测试时，可以调用abort()函数，模拟发送SIGABRT信号，不要联机测试，要脱机测试。
 */
- (IBAction)signalAction {
    [self crashExcClick];
}
- (void)crashSignalEGVClick {
    UIView *view = [[UIView alloc] init];
    [view performSelector:NSSelectorFromString(@"release")];//导致SIGSEGV的错误，一般会导致进程流产
    view.backgroundColor = [UIColor whiteColor];
}

- (void)crashSignalBRTClick {
//    Test *pTest = {1,2};
//    free(pTest);//导致SIGABRT的错误，因为内存中根本就没有这个空间，哪来的free，就在栈中的对象而已
//    pTest->a = 5;
}

- (void)crashSignalBUSClick {
    //SIGBUS，内存地址未对齐
    //EXC_BAD_ACCESS(code=1,address=0x1000dba58)
    char *s = "hello world";
    *s = 'H';
}

- (void)crashExcClick {
    [self performSelector:@selector(aaaa)];
}


@end

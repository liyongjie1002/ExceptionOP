//
//  MQLSignalHandler.m
//  ExceptionOP
//
//  Created by 李永杰 on 2024/2/22.
//

#import <UIKit/UIKit.h>
#import "WSCrashHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#include <sys/signal.h>
NSString * const kSignalExceptionName = @"kSignalExceptionName";
NSString * const kSignalKey = @"kSignalKey";
NSString * const kCaughtExceptionStackInfoKey = @"kCaughtExceptionStackInfoKey";

static void HandleException(NSException *exception);
static void SignalHandler(int signal);

@interface WSCrashHandler ()
@property (nonatomic, assign) BOOL dismissed;
@end

@implementation WSCrashHandler

+ (instancetype)shared {
    static WSCrashHandler *sharedHelper = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedHelper = [[WSCrashHandler alloc] init];
    });
    return sharedHelper;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 1.捕获一些异常导致的崩溃
        NSSetUncaughtExceptionHandler(&HandleException);
        
        // 2.捕获非异常情况，通过signal传递出来的崩溃
        //signal是一个函数，有2个参数，第一个是int类型，第二个参数是一个函数指针
        //添加想要监听的signal类型，当发出相应类型的signal时，会回调SignalHandler方法
        signal(SIGABRT, SignalHandler);// SIGABRT--程序中止命令中止信号
        signal(SIGILL, SignalHandler);//SIGILL--程序非法指令信号
        signal(SIGSEGV, SignalHandler);//SIGSEGV--程序无效内存中止信号
        signal(SIGFPE, SignalHandler);//SIGFPE--程序浮点异常信号
        signal(SIGBUS, SignalHandler);//SIGBUS--程序内存字节未对齐中止信号
        signal(SIGPIPE, SignalHandler);//SIGPIPE--程序Socket发送失败中止信号
    }
    return self;
}

//NSException异常是OC代码导致的crash
void HandleException(NSException *exception) {
    NSString *message = [NSString stringWithFormat:@"崩溃原因如下:\n%@\n%@",
                         [exception reason],
                         [[exception userInfo] objectForKey:kCaughtExceptionStackInfoKey]];
    NSLog(@"%@",message);
    
    // 获取NSException异常的堆栈信息
    NSArray *callStack = [exception callStackSymbols];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:kCaughtExceptionStackInfoKey];
    
    WSCrashHandler *crashObject = [WSCrashHandler shared];
    NSException *customException = [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo];
    [crashObject performSelectorOnMainThread:@selector(handleException:) withObject:customException waitUntilDone:YES];
}
//signal信号抛出的异常处理
void SignalHandler(int signal) {
    NSArray *callStack = [WSCrashHandler backtrace];
    NSLog(@"signal信号捕获崩溃，堆栈信息：%@",callStack);
    
    WSCrashHandler *crashObject = [WSCrashHandler shared];
    NSException *customException = [NSException exceptionWithName:kSignalExceptionName
                                                           reason:[NSString stringWithFormat:NSLocalizedString(@"Signal %d was raised.", nil),signal]
                                                         userInfo:@{kSignalKey:[NSNumber numberWithInt:signal]}];
    
    [crashObject performSelectorOnMainThread:@selector(handleException:) withObject:customException waitUntilDone:YES];
}

- (void)handleException:(NSException *)exception {
    // 打印或弹出框
    // TODO :
#ifdef DEBUG
    NSString *message = [NSString stringWithFormat:@"抱歉，APP发生了异常，点击屏幕继续并自动复制错误信息到剪切板。\n\n异常报告:\n异常名称：%@\n异常原因：%@\n", [exception name], [exception reason]];
    NSLog(@"%@",message);
    [self showCrashToastWithMessage:message];
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (!self.dismissed) {
        for (NSString *mode in (__bridge NSArray *)allModes) {
            //为阻止线程退出，使用 CFRunLoopRunInMode(model, 0.001, false)等待系统消息，false表示RunLoop没有超时时间
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    CFRelease(allModes);
#endif
    // 本地保存exception异常信息并上传服务器
    // TODO :
    
    // 下面等同于清空之前设置的
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    
    // 杀死 或 唤起
    if ([[exception name] isEqual:kSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:kSignalKey] intValue]);
    } else {
        [exception raise];
    }
}

//该函数用来获取当前线程调用堆栈的信息，并且转化为字符串数组。
+ (NSArray *)backtrace {
    void *callStack[128];//堆栈方法数组
    int frames = backtrace(callStack, 128);//获取错误堆栈方法指针数组，返回数目
    char **strs = backtrace_symbols(callStack, frames);//符号化
    
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames]; //函数调用信息依照顺序存在NSMutableArray backtrace
    for (int i = 0; i < frames; i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}

- (void)showCrashToastWithMessage:(NSString *)message {
    UILabel *crashLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 64, [UIApplication sharedApplication].delegate.window.bounds.size.width, [UIApplication sharedApplication].delegate.window.bounds.size.height - 64)];
    crashLabel.textColor = [UIColor redColor];
    crashLabel.font = [UIFont systemFontOfSize:15];
    crashLabel.text = message;
    crashLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    crashLabel.numberOfLines = 0;
    [[UIApplication sharedApplication].delegate.window addSubview:crashLabel];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(crashToastTapAction:)];
    crashLabel.userInteractionEnabled = YES;
    [crashLabel addGestureRecognizer:tap];
}
- (void)crashToastTapAction:(UITapGestureRecognizer *)tap {
    UILabel *crashLabel = (UILabel *)tap.view;
    [UIPasteboard generalPasteboard].string = crashLabel.text;
    self.dismissed = YES;
}

@end


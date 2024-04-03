//
//  NSObject+UnRecognized.m
//  ExceptionOP
//
//  Created by 李永杰 on 2024/2/22.
//

#import "NSObject+UnRecognized.h"
#import <objc/runtime.h>

static NSString *_errorFunctionName;
void dynamicMethodIMP(id self,SEL _cmd) {}

static inline void change_method(Class _originalClass ,SEL _originalSel,Class _newClass ,SEL _newSel) {
    Method methodOriginal = class_getInstanceMethod(_originalClass, _originalSel);
    Method methodNew = class_getInstanceMethod(_newClass, _newSel);
    method_exchangeImplementations(methodOriginal, methodNew);
}

@implementation NSObject(UnRecognized)
+ (void)load {
    change_method([self class], @selector(methodSignatureForSelector:), [self class], @selector(ws_methodSignatureForSelector:));
    change_method([self class], @selector(forwardInvocation:), [self class], @selector(ws_forwardInvocation:));
}

- (NSMethodSignature *)ws_methodSignatureForSelector:(SEL)aSelector {
    if (![self respondsToSelector:aSelector]) {
        _errorFunctionName = NSStringFromSelector(aSelector);
        NSMethodSignature *methodSignature = [self ws_methodSignatureForSelector:aSelector];
        if (class_addMethod([self class], aSelector, (IMP)dynamicMethodIMP, method_getTypeEncoding(class_getInstanceMethod([self class], @selector(methodSignatureForSelector:))))) {
            NSLog(@"添加临时方法成功！");
        }
        if (!methodSignature) {
            methodSignature = [self ws_methodSignatureForSelector:aSelector];
        }
        return methodSignature;
    }else{
        return [self ws_methodSignatureForSelector:aSelector];
    }
}

- (void)ws_forwardInvocation:(NSInvocation *)anInvocation{
    SEL selector = [anInvocation selector];
    if ([self respondsToSelector:selector]) {
        [anInvocation invokeWithTarget:self];
    }else{
        [self ws_forwardInvocation:anInvocation];
    }
}

@end

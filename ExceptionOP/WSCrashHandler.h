//
//  WSCrashHandler.h
//  ExceptionOP
//
//  Created by 李永杰 on 2024/2/22.
//

#import <Foundation/Foundation.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#include <sys/signal.h>

@interface WSCrashHandler : NSObject

+ (instancetype)shared;

@end


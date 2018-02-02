//
//  PPImportArrangerCommand.m
//  ImportArranger
//
//  Created by Vernon on 2018/2/1.
//  Copyright © 2018年 Vernon. All rights reserved.
//

#import "PPImportArrangerCommand.h"

@implementation PPImportArrangerCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError *_Nullable nilOrError))completionHandler
{
    NSMutableArray<NSString *> *lines = invocation.buffer.lines;
    if (!lines || !lines.count) {
        completionHandler(nil);
        return;
    }

    NSMutableArray<NSString *> *importLines = [[NSMutableArray alloc] init];
    NSInteger firstLine = -1;
    for (NSUInteger index = 0, max = lines.count; index < max; index++) {
        NSString *line = lines[index];
        NSString *pureLine = [line stringByReplacingOccurrencesOfString:@" " withString:@""];       // 去掉多余的空格，以防被空格干扰没检测到 #import
        // 支持 Objective-C、Swift、C 语言
        if ([pureLine hasPrefix:@"#import"] || [pureLine hasPrefix:@"import"] || [pureLine hasPrefix:@"@class"]
            || [pureLine hasPrefix:@"@import"] || [pureLine hasPrefix:@"#include"]) {
            [importLines addObject:line];
            if (firstLine == -1) {
                firstLine = index;      // 记住第一行 #import 所在的行数，用来等下重新插入的位置
            }
        }
    }

    if (!importLines.count) {
        completionHandler(nil);
        return;
    }

    [invocation.buffer.lines removeObjectsInArray:importLines];

    NSArray *noRepeatArray = [[NSSet setWithArray:importLines] allObjects];         // 去掉重复的 #import
    NSMutableArray<NSString *> *sortedImports = [[NSMutableArray alloc] initWithArray:[noRepeatArray sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];

    // 引用系统文件在前，用户自定义的文件在后
    NSMutableArray *systemImports = [[NSMutableArray alloc] init];
    for (NSString *line in sortedImports) {
        if ([line containsString:@"<"]) {
            [systemImports addObject:line];
        }
    }
    if (systemImports.count) {
        [sortedImports removeObjectsInArray:systemImports];
        [sortedImports insertObjects:systemImports atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, systemImports.count)]];
    }

    if (firstLine >= 0 && firstLine < invocation.buffer.lines.count) {
        // 重新插入排好序的 #import 行
        [invocation.buffer.lines insertObjects:sortedImports atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstLine, sortedImports.count)]];
        // 选中所有 #import 行
        [invocation.buffer.selections addObject:[[XCSourceTextRange alloc] initWithStart:XCSourceTextPositionMake(firstLine, 0) end:XCSourceTextPositionMake(firstLine + sortedImports.count, sortedImports.lastObject.length)]];
    }

    completionHandler(nil);
}

@end

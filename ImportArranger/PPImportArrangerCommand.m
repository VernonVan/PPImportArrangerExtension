//
//  PPImportArrangerCommand.m
//  ImportArranger
//
//  Created by Vernon on 2018/2/1.
//  Copyright © 2018年 Vernon. All rights reserved.
//

#import "PPImportArrangerCommand.h"

#define ArrangeSelectedLines @"ArrangeSelectedLines"

@implementation PPImportArrangerCommand {
    NSMutableArray<NSString *> *_classNames;
    BOOL _isSelectedLines;
}

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError *_Nullable nilOrError))completionHandler
{
    NSArray<NSString *> *lines = nil;
    NSInteger firstLine = -1;
    if ([invocation.commandIdentifier hasSuffix:ArrangeSelectedLines]) {
        XCSourceTextRange *textRange = invocation.buffer.selections.firstObject;
        NSRange selectedLineRange = NSMakeRange(textRange.start.line, textRange.end.line - textRange.start.line + 1);
        lines = [invocation.buffer.lines subarrayWithRange:selectedLineRange];
        firstLine = textRange.start.line;
        _isSelectedLines = YES;
    } else {
        lines = invocation.buffer.lines;
        _isSelectedLines = NO;
    }

    if (!lines || !lines.count) {
        completionHandler(nil);
        return;
    }

    NSMutableArray<NSString *> *importLines = [[NSMutableArray alloc] init];
    _classNames = [[NSMutableArray alloc] init];

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
        } else if ([pureLine hasPrefix:@"@implementation"]) {
            NSString *className = [pureLine stringByReplacingOccurrencesOfString:@"@implementation" withString:@""];
            className = [className stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            [_classNames addObject:className];
        }
    }

    if (!importLines.count) {
        completionHandler(nil);
        return;
    }

    // 先从源文件中移除所有 import 的行
    [invocation.buffer.lines removeObjectsInArray:importLines];
    NSMutableArray<NSString *> *sortedImportLines = [self sortImportLines:importLines];

    if (firstLine >= 0 && firstLine < invocation.buffer.lines.count) {
        // 重新插入排好序的 #import 行
        [invocation.buffer.lines insertObjects:sortedImportLines atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(firstLine, sortedImportLines.count)]];
        // 选中所有 #import 行
        [invocation.buffer.selections addObject:[[XCSourceTextRange alloc] initWithStart:XCSourceTextPositionMake(firstLine, 0) end:XCSourceTextPositionMake(firstLine + sortedImportLines.count - 1, sortedImportLines.lastObject.length)]];
    }

    completionHandler(nil);
}

- (NSMutableArray<NSString *> *)sortImportLines:(NSMutableArray<NSString *> *)importLines
{
    NSArray *noRepeatArray = [[NSSet setWithArray:importLines] allObjects];  // 去掉重复的 #import
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
    
    // 把当前文件对应的头文件放在最前面
    NSString *currentHeaderLine = nil;
    if (!_isSelectedLines && _classNames.count) {
        for (NSString *className in _classNames) {
            for (NSString *line in sortedImports) {
                if ([line containsString:className]) {
                    currentHeaderLine = line;
                    break;
                }
            }
        }
    }
    if (currentHeaderLine) {
        [sortedImports removeObject:currentHeaderLine];
        [sortedImports insertObject:currentHeaderLine atIndex:0];
    }

    return sortedImports;
}

@end

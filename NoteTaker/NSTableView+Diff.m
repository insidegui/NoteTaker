//
//  NSTableView+Diff.m
//  Dose
//
//  Created by Guilherme Rambo on 09/01/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

#import "NSTableView+Diff.h"

@implementation NSTableView (Diff)

- (void)reloadDataWithOldValue:(NSArray <id<IGListDiffable>> *)oldValue newValue:(NSArray <id<IGListDiffable>> *)newValue
{
    IGListIndexSetResult *result = IGListDiffWithBehavior(oldValue, newValue, IGListDiffEquality, IGListDiffBehaviorIncrementalMoves);
    
    [self beginUpdates];
    {
        [self reloadDataForRowIndexes:result.updates columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableColumns.count)]];
        [self insertRowsAtIndexes:result.inserts withAnimation:NSTableViewAnimationSlideDown];
        [self removeRowsAtIndexes:result.deletes withAnimation:NSTableViewAnimationSlideUp];
        [result.moves enumerateObjectsUsingBlock:^(IGListMoveIndex *index, NSUInteger idx, BOOL *stop) {
            [self moveRowAtIndex:index.from toIndex:index.to];
        }];
    }
    [self endUpdates];
}

@end

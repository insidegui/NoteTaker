//
//  NSTableView+Diff.h
//  Dose
//
//  Created by Guilherme Rambo on 09/01/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

@import Cocoa;
@import IGListKit;

@interface NSTableView (Diff)

- (void)reloadDataWithOldValue:(NSArray <id<IGListDiffable>> *)oldValue newValue:(NSArray <id<IGListDiffable>> *)newValue;

@end

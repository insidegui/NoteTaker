//
//  NoteTakerCore.h
//  NoteTakerCore
//
//  Created by Guilherme Rambo on 27/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_SIMULATOR || TARGET_OS_IOS
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif

//! Project version number for NoteTakerCore.
FOUNDATION_EXPORT double NoteTakerCoreVersionNumber;

//! Project version string for NoteTakerCore.
FOUNDATION_EXPORT const unsigned char NoteTakerCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <NoteTakerCore/PublicHeader.h>



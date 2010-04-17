//
//  GCPingAppDelegate.h
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GCPingViewController;

@interface GCPingAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    GCPingViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet GCPingViewController *viewController;

@end


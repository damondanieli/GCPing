//
//  GCPingAppDelegate.m
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import "GCPingAppDelegate.h"
#import "GCPingViewController.h"

@implementation GCPingAppDelegate

@synthesize window;
@synthesize viewController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
    // Override point for customization after app launch    
	return YES;
}


- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end

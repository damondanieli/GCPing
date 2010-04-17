//
//  GCPingAppDelegate.m
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright Damon Danieli 2010. All rights reserved.
//

#import "GCPingAppDelegate.h"
#import "GCPingViewController.h"
#import "DDLog.h"

@implementation GCPingAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    DDLog(@"launchOptions=%@", launchOptions);

    return YES;
}

- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end

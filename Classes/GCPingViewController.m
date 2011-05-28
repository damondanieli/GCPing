//
//  GCPingViewController.m
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright Damon Danieli 2010. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import "DDLog.h"
#import "GCPingViewController.h"

BOOL isGameCenterAPIAvailable();

@interface GCPingViewController ()
- (void)setupGameCenter;
- (void)showNoGameCenter;
- (void)startUserAuthentication;
- (void)createGameSessionWithMatch:(GKMatch *)match;
- (void)showMatchmakerWithRequest:(GKMatchRequest *)request;
- (void)showMatchmakerWithInvite:(GKInvite *)invite;
- (void)showErrorMessage:(NSString *)errorMessage;
- (void)showError:(NSError *)error;
@end

@implementation GCPingViewController

- (void)dealloc {
    AudioSessionSetActive(false);
    
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (isGameCenterAPIAvailable()) {
        [self setupGameCenter];
    } else {
        [self showNoGameCenter];
    }
}

- (void)awakeFromNib {
#if __IPHONE_4_2 <= __IPHONE_OS_VERSION_MAX_ALLOWED
    // Temporary fix for viewDidLoad being called twice
    // Do NOT call super
    // https://devforums.apple.com/message/409261#409261
#else
    [super awakeFromNib];
#endif
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)signInButtonPressed:(id)sender {
    DDLog(@"");

    [self startUserAuthentication];
}

- (IBAction)startGameButtonPressed:(id)sender {
    DDLog(@"");
    
    GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
    request.minPlayers = minPlayersSegmentedControl.selectedSegmentIndex + 2;
    request.maxPlayers = maxPlayersSegmentedControl.selectedSegmentIndex + 2;

    [self showMatchmakerWithRequest:request];
}

#pragma mark -
#pragma mark GKMatchmakerViewControllerDelegate methods

- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)matchmakerViewController {
    DDLog(@"");

    [matchmakerViewController dismissModalViewControllerAnimated:YES];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)matchmakerViewController didFindMatch:(GKMatch *)match {
    DDLog(@"match=%@", match);
    
    [matchmakerViewController dismissModalViewControllerAnimated:NO];

    [self createGameSessionWithMatch:match];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)matchmakerViewController didFailWithError:(NSError *)error {
    DDLog(@"error=%@", error);

    [matchmakerViewController dismissModalViewControllerAnimated:YES];
    
    [self showError:error];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)matchmakerViewController didFindPlayers:(NSArray *)players {
    DDLog(@"players=%@", players);
}

#pragma mark -
#pragma mark Helpers

- (void)setupAudioSession {
    DDLog(@"");
    
    OSStatus osRes = 0;
    osRes = AudioSessionInitialize(NULL, NULL, NULL, NULL);
    if (osRes) {
        DDLog(@"Initializing Audio Session Failed: %ld", (long)osRes);
    }
    
    osRes = AudioSessionSetActive(true);
    if (osRes) {
        DDLog(@"AudioSessionSetActive Failed: %ld", (long)osRes);
    }
    
    UInt32 category = kAudioSessionCategory_PlayAndRecord;
    osRes = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    if (osRes) {
        DDLog(@"AudioSessionSetProperty kAudioSessionCategory_PlayAndRecord Failed: %ld", (long)osRes);
    }
    UInt32 allowMixing = true;
    osRes = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(allowMixing), &allowMixing);
    if (osRes) {
        DDLog(@"AudioSessionSetProperty kAudioSessionProperty_OverrideCategoryMixWithOthers Failed: %ld", (long)osRes);
    }
    UInt32 route = kAudioSessionOverrideAudioRoute_Speaker;
    osRes = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(route), &route);
    if (osRes) {
        DDLog(@"AudioSessionSetProperty kAudioSessionOverrideAudioRoute_Speaker Failed: %ld", (long)osRes);
    }
}

- (void)setupGameCenter {
    DDLog(@"");

    [self setupAudioSession];
    
    [self startUserAuthentication];
}

- (void)showNoGameCenter {
    DDLog(@"");
    signInButton.enabled = NO;
    [self showErrorMessage:@"Game Center is not available"];
}

- (void)setupInviteHandler {
    DDLog(@"");

    [[GKMatchmaker sharedMatchmaker] setInviteHandler:^(GKInvite *invite, NSArray *playersToInvite) {
        [self showMatchmakerWithInvite:invite];
    }];
}

- (void)localPlayerDidAuthenticate {
    signInButton.hidden = YES;
    startGameButton.hidden = NO;
    
    [self setupInviteHandler];
}

- (NSString *)decodeAuthenticationError:(NSError *)error {
    NSString *errorMessage = [error localizedDescription];
    // Add additional information to developer if we know what causes this error
    if ([errorMessage isEqualToString:@"The requested operation could not be completed because this application is not recognized by Game Center."]) {
        // There are several reasons
        errorMessage = @"In iTunesConnect, create an application but do not upload a binary, then go to Manage Game Center and click Enable";
    }
    return errorMessage;
}

- (void)localPlayerDidFailToAuthenticateWithError:(NSError *)error {
    signInButton.hidden = NO;

    [self showErrorMessage:[self decodeAuthenticationError:error]];
}

- (void)startUserAuthentication {
    DDLog(@"");
    [activityIndicatorView startAnimating];
    
    GKLocalPlayer *player = [GKLocalPlayer localPlayer];
    [player authenticateWithCompletionHandler:^(NSError *error) {
        [activityIndicatorView stopAnimating];
        
        if (error) {
            [self localPlayerDidFailToAuthenticateWithError:error];
        }
        else {
            [self localPlayerDidAuthenticate];
        }
    }];
}

- (void)createGameSessionWithMatch:(GKMatch *)match {
    DDLog(@"match=%@", match);
    
    GameSessionViewController *gsvc = [[[GameSessionViewController alloc] initWithDelegate:self withMatch:match] autorelease];
    [self presentModalViewController:gsvc animated:YES];
}

- (void)showMatchmaker:(GKMatchmakerViewController *)matchmakerViewController {
    matchmakerViewController.matchmakerDelegate = self;
    matchmakerViewController.hosted = NO;
    [self presentModalViewController:matchmakerViewController animated:YES];
}

- (void)showMatchmakerWithRequest:(GKMatchRequest *)request {
    DDLog(@"");
    
    [self showMatchmaker:[[GKMatchmakerViewController alloc] initWithMatchRequest:request]];
}

- (void)showMatchmakerWithInvite:(GKInvite *)invite {
    DDLog(@"invite=%@", invite);
    
    [activityIndicatorView stopAnimating];
    
    [self showMatchmaker:[[GKMatchmakerViewController alloc] initWithInvite:invite]];
}

- (void)showErrorMessage:(NSString *)errorMessage {
    [[[[UIAlertView alloc] initWithTitle:@"Error" 
                                 message:errorMessage 
                                delegate:nil 
                       cancelButtonTitle:@"Dismiss" 
                       otherButtonTitles:nil] autorelease] 
     show];
    
}

- (void)showError:(NSError *)error {
    DDLog(@"error=%@", error);
    [self showErrorMessage:[error localizedDescription]];
}

#pragma mark -
#pragma mark Game Center Helpers

// Check for the availability of Game Center API. 
BOOL isGameCenterAPIAvailable()
{
    // Check for presence of GKLocalPlayer API.
    Class gcClass = (NSClassFromString(@"GKLocalPlayer"));
    
    // The device must be running running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    return (gcClass && osVersionSupported); 
}

#pragma mark -
#pragma mark GameSessionViewControllerDelegate

- (void)gameSessionViewControllerWasClosed:(GameSessionViewController *)gameSessionViewController {
    [gameSessionViewController dismissModalViewControllerAnimated:YES];
}

@end

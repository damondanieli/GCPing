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

@interface GCPingViewController ()
- (void)setupAudioSession;
- (void)startUserAuthentication;
- (void)createGameSessionWithMatch:(GKMatch *)match;
- (void)showMatchmakerWithRequest:(GKMatchRequest *)request;
- (void)showMatchmakerWithInvite:(GKInvite *)invite;
- (void)showError:(NSError *)error;
@end

@implementation GCPingViewController

- (void)dealloc {
    AudioSessionSetActive(false);
    
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupAudioSession];
    [self startUserAuthentication];
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

- (void)localPlayerDidFailToAuthenticateWithError:(NSError *)error {
    signInButton.hidden = NO;

    [self showError:error];
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


- (void)showError:(NSError *)error {
    DDLog(@"error=%@", error);

    [[[[UIAlertView alloc] initWithTitle:@"Error" 
                                 message:[error localizedDescription] 
                                delegate:nil 
                       cancelButtonTitle:@"Dismiss" 
                       otherButtonTitles:nil] autorelease] 
     show];
}

#pragma mark -
#pragma mark GameSessionViewControllerDelegate

- (void)gameSessionViewControllerWasClosed:(GameSessionViewController *)gameSessionViewController {
    [gameSessionViewController dismissModalViewControllerAnimated:YES];
}

@end

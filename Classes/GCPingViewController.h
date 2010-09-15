//
//  GCPingViewController.h
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright Damon Danieli 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import "GameSessionViewController.h"

@interface GCPingViewController : UIViewController <GKMatchmakerViewControllerDelegate, GameSessionViewControllerDelegate> {
    IBOutlet UIActivityIndicatorView *activityIndicatorView;
    IBOutlet UIButton *signInButton;
    IBOutlet UIButton *startGameButton;
    
    IBOutlet UISegmentedControl *minPlayersSegmentedControl;
    IBOutlet UISegmentedControl *maxPlayersSegmentedControl;
}

- (IBAction)signInButtonPressed:(id)sender;
- (IBAction)startGameButtonPressed:(id)sender;
@end

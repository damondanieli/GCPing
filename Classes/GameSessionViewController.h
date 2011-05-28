//
//  GameSessionViewController.h
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright 2010 Damon Danieli. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol GameSessionViewControllerDelegate;

@interface GameSessionViewController : UIViewController <GKMatchDelegate, UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate> {
    id<GameSessionViewControllerDelegate> delegate;
    
    UILabel *localPlayerNameLabel;
    UILabel *statusLabel;
    UILabel *voicechatLabel;
    UIButton *pingButton;
    UITableView *playerStatusTableView;

@private
    GKMatch *_match;
    GKVoiceChat *_voiceChat;
    NSTimer *_pingTimer;
    NSMutableArray *_playerStatus;

    UIAlertView *_alertView;

    CFURLRef pingSoundURLRef;
    SystemSoundID pingSound;
}

@property (nonatomic, assign) id<GameSessionViewControllerDelegate> delegate;
@property (nonatomic, retain) IBOutlet UILabel *localPlayerNameLabel;
@property (nonatomic, retain) IBOutlet UILabel *statusLabel;
@property (nonatomic, retain) IBOutlet UILabel *voicechatLabel;
@property (nonatomic, retain) IBOutlet UIButton *pingButton;
@property (nonatomic, retain) IBOutlet UITableView *playerStatusTableView;

- (id)initWithDelegate:(id<GameSessionViewControllerDelegate>)delegate withMatch:(GKMatch *)match;

- (IBAction)pingButtonPressed:(id)sender;
- (IBAction)disconnectButtonPressed:(id)sender;
- (IBAction)voiceChatSwitchValueChanged:(id)sender;
- (IBAction)microphoneSwitchValueChanged:(id)sender;
- (IBAction)volumeSliderValueChanged:(id)sender;

@end

@protocol GameSessionViewControllerDelegate <NSObject>
- (void)gameSessionViewControllerWasClosed:(GameSessionViewController *)gameSessionViewController;
@end

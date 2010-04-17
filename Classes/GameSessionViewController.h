//
//  GameSessionViewController.h
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKitBeta.h>

@protocol GameSessionViewControllerDelegate;

@interface GameSessionViewController : UIViewController <GKMatchDelegate, UIAlertViewDelegate> {
    id<GameSessionViewControllerDelegate> delegate;
    
    IBOutlet UILabel *statusLabel;
    IBOutlet UILabel *voicechatLabel;
    IBOutlet UIButton *pingButton;

@private
    GKMatch *_match;
    GKVoiceChat *_voiceChat;
    NSTimer *_pingTimer;
    UIAlertView *_alertView;
}

@property (nonatomic, assign) id<GameSessionViewControllerDelegate> delegate;
@property (nonatomic, retain) UILabel *statusLabel;

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

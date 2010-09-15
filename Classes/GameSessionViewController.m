//
//  GameSessionViewController.m
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright 2010 Damon Danieli. All rights reserved.
//

#import "GameSessionViewController.h"
#import "DDLog.h"

#define kShowConnectingTag    1
#define kConfirmDisconnectTag 2
#define kShowDisconnectedTag  3

@interface GameSessionViewController ()
@property (nonatomic, retain) GKMatch *match;
@property (nonatomic, retain) GKVoiceChat *voiceChat;
@property (nonatomic, retain) NSTimer *pingTimer;

- (void)updateStatus:(NSTimer *)theTimer;
- (void)setStatus:(NSString *)status;
- (void)disconnect;
- (void)confirmDisconnect;
- (void)showConnecting;
- (void)showConnected:(NSString *)playerName;
- (void)showDisconnected:(NSString *)playerName;
- (void)showGameReady;
- (void)enableVoiceChat:(BOOL)enable;
- (void)preparePingSound;
- (void)unpreparePingSound;
- (void)playPingSound;
@end

@implementation GameSessionViewController

@synthesize delegate;
@synthesize statusLabel;
@synthesize match = _match;
@synthesize voiceChat = _voiceChat;
@synthesize pingTimer = _pingTimer;

- (UIAlertView *)alertView {
    return _alertView;
}

- (void)setAlertView:(UIAlertView *)value {
    // Network events can cause multiple UIAlertViews to be shown
    if (_alertView) {
        _alertView.delegate = nil;
        [_alertView dismissWithClickedButtonIndex:-1 animated:NO];
    }
    _alertView = value;
}

- (void)dealloc {
    self.alertView = nil;
    
    [self unpreparePingSound];

    [self disconnect];

    [statusLabel release];

    [_match release];
    [_voiceChat release];
    [_pingTimer invalidate];
    [_pingTimer release];
    
    [super dealloc];
}

- (id)initWithDelegate:(id<GameSessionViewControllerDelegate>)d withMatch:(GKMatch *)m {
    if (self = [super init]) {
        self.delegate = d;
        self.match = m;
        _match.delegate = self;

        [self preparePingSound];

        [self enableVoiceChat:YES];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [self showConnecting];
}

#pragma mark -
#pragma mark GKMatchDelegate methods

- (void)updateStatus:(NSTimer *)theTimer {
    DDLog(@"");

    [self setStatus:@""];
}

- (void)showPinged {
    DDLog(@"");

    [self playPingSound];

    self.statusLabel.text = @"Pinged!";
    [_pingTimer invalidate];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStatus:) userInfo:nil repeats:NO];
}

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID
{
    DDLog(@"match=%@, data=%@ player=%@", match, data, playerID);
    
    [self showPinged];
}

- (void)match:(GKMatch *)match player:(NSString *)playerID didChangeState:(GKPlayerConnectionState)state {
    DDLog(@"match=%@, data=%@ state=%ld", match, playerID, (long)state);

    switch (state) {
        case GKPlayerStateConnected:
			[GKPlayer loadPlayersForIdentifiers:[NSArray arrayWithObject:playerID]
						  withCompletionHandler:^(NSArray *players, NSError *error) {
							  if ([players count] == 1) {
								  GKPlayer * player = [players objectAtIndex:0];
								  [self showConnected:player.alias];
							  }
						  }];
            
            if (match.expectedPlayerCount == 0) {
                [self showGameReady];
            }
            break;
        case GKPlayerStateDisconnected:
			[GKPlayer loadPlayersForIdentifiers:[NSArray arrayWithObject:playerID]
						  withCompletionHandler:^(NSArray *players, NSError *error) {
							  if ([players count] == 1) {
								  GKPlayer * player = [players objectAtIndex:0];
								  [self showDisconnected:player.alias];
							  }
						  }];
            break;
        default:
            break;
    }
}

#pragma mark -
#pragma mark IBActions

- (IBAction)pingButtonPressed:(id)sender {
    DDLog(@"");

    NSError *error;
    if ( ! [_match sendDataToAllPlayers:[NSData dataWithBytes:"ping" length:5] withDataMode:GKMatchSendDataReliable error:&error]) {
        if (error != nil) {
            DDLog(@"error=%@", [error localizedDescription]);
        }
    }
}

- (IBAction)disconnectButtonPressed:(id)sender {
    DDLog(@"");

    [self confirmDisconnect];
}

- (IBAction)voiceChatSwitchValueChanged:(id)sender {
    DDLog(@"");
    
    [self enableVoiceChat:((UISwitch *)sender).on];
}

- (IBAction)microphoneSwitchValueChanged:(id)sender {
    DDLog(@"");
    _voiceChat.active = ((UISwitch *)sender).on;
}

- (IBAction)volumeSliderValueChanged:(id)sender {
    DDLog(@"");

    _voiceChat.volume = ((UISlider *)sender).value;
}

#pragma mark -
#pragma mark Helpers

- (void)setStatus:(NSString *)status {
    DDLog(@"status=%@", status);

    self.statusLabel.text = status;
}

- (void)disconnect {
    DDLog(@"");
    if (_match != nil) {
        [_voiceChat stop];
        self.voiceChat = nil;
        
        _match.delegate = nil;
        [_match disconnect];
        self.match = nil;
    }
}

- (void)showConnecting {
    DDLog(@"");
}

- (void)showConnected:(NSString *)playerName {
    DDLog(@"playerName=%@", playerName);
    [self setStatus:[NSString stringWithFormat:@"%@ connected", playerName]];
}

- (void)showDisconnected:(NSString *)playerName {
    DDLog(@"playerName=%@", playerName);

    [self setStatus:@""];

    self.alertView = [[[UIAlertView alloc] initWithTitle:@"Player Disconnected"
                                                 message:[NSString stringWithFormat:@"%@ left the session.", playerName]
                                                delegate:self 
                                       cancelButtonTitle:@"Close"
                                       otherButtonTitles:nil] autorelease];
    _alertView.tag = kShowDisconnectedTag;
    [_alertView show];
}

- (void)showGameReady {
    DDLog(@"");
    
    self.alertView = nil;
}

- (void)confirmDisconnect {
    DDLog(@"");
    
    self.alertView = [[[UIAlertView alloc] initWithTitle:@"Leave Session" 
                                                 message:@"Are you sure?"
                                                delegate:self 
                                       cancelButtonTitle:@"Cancel"
                                       otherButtonTitles:@"Disconnect", nil] autorelease];
    _alertView.tag = kConfirmDisconnectTag;
    [_alertView show];
}

- (void)sessionDisconnected {
    DDLog(@"");

    [self disconnect];

    [[self retain] autorelease];
    [self.delegate gameSessionViewControllerWasClosed:self];
}

- (void)enableVoiceChat:(BOOL)enable {
    DDLog(@"enable=%@", enable ? @"YES" : @"NO");

    if (enable) {
        if (_voiceChat == nil) {
            self.voiceChat = [_match voiceChatWithName:@"PING"];
        }
        
        [_voiceChat start];
    }
    else {
        [_voiceChat stop];
    }
    _voiceChat.active = enable;
}

- (void)preparePingSound {
    DDLog(@"");

    CFBundleRef mainBundle = CFBundleGetMainBundle ();
    pingSoundURLRef = CFBundleCopyResourceURL(mainBundle, CFSTR("ping"), CFSTR ("wav"), NULL);
    AudioServicesCreateSystemSoundID(pingSoundURLRef, &pingSound);
}

- (void)unpreparePingSound {
    DDLog(@"");

    AudioServicesDisposeSystemSoundID(pingSound);
    CFRelease(pingSoundURLRef);
    pingSound = (SystemSoundID)nil;
    pingSoundURLRef = nil;
}

- (void)playPingSound {
    DDLog(@"");

    AudioServicesPlaySystemSound(pingSound);
}

#pragma mark -
#pragma mark UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    DDLog(@"tag=%ld, buttonIndex=%ld", (long)alertView.tag, (long)buttonIndex);

    // Network events can cause multiple alert views to be shown
    _alertView = nil;

    switch(alertView.tag) {
        case kShowConnectingTag:
            [self sessionDisconnected];
            break;
        case kConfirmDisconnectTag:
            if (buttonIndex == 1) {
                [self sessionDisconnected];
            }
            break;
        case kShowDisconnectedTag:
			[self sessionDisconnected];
            break;
        default:
            break;
    }
}

@end

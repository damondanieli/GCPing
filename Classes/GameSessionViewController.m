//
//  GameSessionViewController.m
//  GCPing
//
//  Created by Damon Danieli on 4/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GameSessionViewController.h"
#import "DDLog.h"

#define kConfirmDisconnectTag 1
#define kShowDisconnectedTag  2

@interface GameSessionViewController ()
@property (nonatomic, retain) GKMatch *match;
@property (nonatomic, retain) GKVoiceChat *voiceChat;
@property (nonatomic, retain) NSTimer *pingTimer;

- (void)updateStatus:(NSTimer *)theTimer;
- (void)setStatus:(NSString *)status;
- (void)disconnect;
- (void)confirmDisconnect;
- (void)showConnected:(NSString *)playerName;
- (void)showDisconnected:(NSString *)playerName;
- (void)enableVoiceChat:(BOOL)enable;
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

        [self enableVoiceChat:YES];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setStatus:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

#pragma mark -
#pragma mark GKMatchDelegate methods

- (void)updateStatus:(NSTimer *)theTimer {
    DDLog(@"");

    [self setStatus:nil];
}

- (void)showPinged {
    DDLog(@"");

    self.statusLabel.text = @"Pinged!";
    [_pingTimer invalidate];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateStatus:) userInfo:nil repeats:NO];
}

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(GKPlayer *)player {
    DDLog(@"match=%@, data=%@ player=%@", match, data, player);
    
    [self showPinged];
}

- (void)match:(GKMatch *)match player:(GKPlayer *)player didChangeState:(GKPlayerConnectionState)state {
    DDLog(@"match=%@, data=%@ state=%ld", match, player, (long)state);

    switch (state) {
        case GKPlayerStateConnected:
            [self showConnected:player.alias];
            break;
        case GKPlayerStateDisconnected:
            [self showDisconnected:player.alias];
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
    [_match sendDataToAllPlayers:[NSData dataWithBytes:"ping" length:5] withDataMode:GKMatchSendDataReliable error:&error];
    if (error != nil) {
        DDLog(@"error=%@", [error localizedDescription]);
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
    DDLog(@"");
    if (status = nil) {
        status = @"Waiting...";
    }
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

- (void)showConnected:(NSString *)playerName {
    DDLog(@"playerName=%@", playerName);
    [self setStatus:[NSString stringWithFormat:@"%@ connected", playerName]];
}

- (void)showDisconnected:(NSString *)playerName {
    DDLog(@"playerName=%@", playerName);

    [self setStatus:@""];

    self.alertView = [[[UIAlertView alloc] initWithTitle:@"Game Over"
                                                 message:[NSString stringWithFormat:@"%@ disconnected.", playerName]
                                                delegate:self 
                                       cancelButtonTitle:@"Close"
                                       otherButtonTitles:nil] autorelease];
    _alertView.tag = kShowDisconnectedTag;
    [_alertView show];
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

#pragma mark -
#pragma mark UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    DDLog(@"tag=%ld, buttonIndex=%ld", (long)alertView.tag, (long)buttonIndex);

    // Network events can cause multiple alert views to be shown
    _alertView = nil;

    switch(alertView.tag) {
        case kConfirmDisconnectTag:
            if (buttonIndex == 1) {
                [self sessionDisconnected];
            }
            break;
        case kShowDisconnectedTag:
            if ([_match.players count] == 0) {
                [self sessionDisconnected];
            }
            break;
        default:
            break;
    }
}

@end

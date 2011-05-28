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

#define kGCPingMessageKeyCommand  @"cmd"
#define kGCPingMessageKeyParams   @"params"
#define kGCPingMessageKeyTimeSent @"timeSent"

typedef const NSString *GCPingCommand;
GCPingCommand kGCPingCommandUnknown = nil;
GCPingCommand kGCPingCommandPing = @"ping";
GCPingCommand kGCPingCommandPong = @"pong";

#define kGCPingPlayerStatusKeyID     @"playerID"
#define kGCPingPlayerStatusKeyName   @"name"
#define kGCPingPlayerStatusKeyStatus @"status"
#define kGCPingStatusConnected       @"connected"
#define kGCPingStatusDisconnected    @"disconnected"
#define kGCPingStatusPinging         @"pinging"

@interface GameSessionViewController ()
@property (nonatomic, retain) GKMatch *match;
@property (nonatomic, retain) GKVoiceChat *voiceChat;
@property (nonatomic, retain) NSTimer *pingTimer;
@property (nonatomic, retain) NSMutableArray *playerStatus;
- (void)statusTimerFired:(NSTimer *)theTimer;
- (void)setStatus:(NSString *)status;
- (void)disconnect;
- (void)confirmDisconnect;
- (void)showConnecting;
- (void)showDisconnected:(NSString *)playerName;
- (void)showGameReady;
- (void)enableVoiceChat:(BOOL)enable;
- (void)preparePingSound;
- (void)unpreparePingSound;
- (void)playPingSound;
- (void)showErrorMessage:(NSString *)errorMessage;
- (void)showError:(NSError *)error;
@end

@implementation GameSessionViewController

@synthesize delegate;
@synthesize localPlayerNameLabel;
@synthesize statusLabel;
@synthesize voicechatLabel;
@synthesize pingButton;
@synthesize addPlayersButton;
@synthesize playerStatusTableView;

@synthesize match = _match;
@synthesize voiceChat = _voiceChat;
@synthesize pingTimer = _pingTimer;
@synthesize playerStatus = _playerStatus;

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
    self.delegate = nil;
    
    [self unpreparePingSound];

    [self disconnect];

    [localPlayerNameLabel release];
    [statusLabel release];
    [voicechatLabel release];
    [pingButton release];
    [addPlayersButton release];
    [playerStatusTableView release];

    [_match release];
    [_voiceChat release];
    [_pingTimer invalidate];
    [_pingTimer release];
    [_playerStatus release];
    
    [super dealloc];
}

- (id)initWithDelegate:(id<GameSessionViewControllerDelegate>)d withMatch:(GKMatch *)m {
    self = [super init];
    if (self) {
        self.delegate = d;
        self.match = m;
        _match.delegate = self;
        
        self.playerStatus = [NSMutableArray array];

        [self enableVoiceChat:NO];
        [self preparePingSound];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    localPlayerNameLabel.text = [GKLocalPlayer localPlayer].alias;
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
#pragma mark Network Messages

- (NSData *)dataFromMessage:(GCPingCommand)command withParams:(NSDictionary *)params {
    DDLog(@"command=%@, params=%@", command, params);

    if (params == nil) {
        params = [NSDictionary dictionary];
    }
    NSDictionary *cmd = [NSMutableDictionary dictionaryWithObjectsAndKeys:command, kGCPingMessageKeyCommand, params, kGCPingMessageKeyParams, nil];
    return [NSKeyedArchiver archivedDataWithRootObject:cmd];
}

- (NSDictionary *)messageFromData:(NSData *)data {
    DDLog(@"");

    NSDictionary *message = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSAssert(message, @"Data from message should unarchive");
    NSAssert([message isKindOfClass:[NSDictionary class]], @"Data expected to be NSDictionary");
    return message;
}

- (GCPingCommand)commandFromMessage:(NSDictionary *)message {
    DDLog(@"message=%@", message);

    NSString *commandString = [message objectForKey:kGCPingMessageKeyCommand];
    if ([kGCPingCommandPing isEqualToString:commandString]) {
        return kGCPingCommandPing;
    }
    else if ([kGCPingCommandPong isEqualToString:commandString]) {
        return kGCPingCommandPong;
    }
    return kGCPingCommandUnknown;
}

- (NSDictionary *)paramsFromMessage:(NSDictionary *)message {
    DDLog(@"message=%@", message);

    NSDictionary *params = [message objectForKey:kGCPingMessageKeyParams];
    if (params == nil) {
        params = [NSDictionary dictionary];
    }
    return params;
}

- (void)sendCommand:(GCPingCommand)command withParams:(NSDictionary *)params toPlayer:(NSString *)playerID {
    DDLog(@"playerID=%@", playerID);
    
    NSData *data = [self dataFromMessage:command withParams:params];
    NSError *error;
    if ( ! [_match sendData:data toPlayers:[NSArray arrayWithObject:playerID] withDataMode:GKMatchSendDataReliable error:&error]) {
        if (error != nil) {
            [self showError:error];
        }
    }
}

- (NSMutableDictionary *)playerStatusFromID:(NSString *)playerID {
    NSMutableDictionary *ps = nil;
    for (NSMutableDictionary *dict in _playerStatus) {
        if ([playerID isEqualToString:[dict objectForKey:kGCPingPlayerStatusKeyID]]) {
            ps = dict;
            break;
        }
    }
    return ps;
}

- (void)updateStatus:(NSString *)status forPlayerID:(NSString *)playerID {
    DDLog(@"status=%@, playerID=%@", status, playerID);
    
    [[self playerStatusFromID:playerID] setObject:status forKey:kGCPingPlayerStatusKeyStatus];
    [playerStatusTableView reloadData];
}

- (void)sendPingToPlayer:(NSString *)playerID {
    NSNumber *timeSent = [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]];
    NSDictionary *params = [NSDictionary dictionaryWithObject:timeSent forKey:kGCPingMessageKeyTimeSent];
    [self sendCommand:kGCPingCommandPing withParams:params toPlayer:playerID];
    [self updateStatus:kGCPingStatusPinging forPlayerID:playerID];
}

- (void)sendPingToAllPlayers {
    for (NSString *playerID in _match.playerIDs) {
        [self sendPingToPlayer:playerID];
    }
}

- (void)sendPongToPlayer:(NSString *)playerID withParams:(NSDictionary *)params {
    [self sendCommand:kGCPingCommandPong withParams:params toPlayer:playerID];
}

#pragma mark -
#pragma mark GKMatchDelegate methods

- (void)statusTimerFired:(NSTimer *)theTimer {
    DDLog(@"");

    [self setStatus:@""];
}

- (void)showPinged {
    DDLog(@"");

    [self playPingSound];

    self.statusLabel.text = @"Pinged!";
    [_pingTimer invalidate];
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(statusTimerFired:) userInfo:nil repeats:NO];
}

- (void)updateAddPlayersButton {
    BOOL canAddPlayers = (_playerStatus.count < 3);
    addPlayersButton.enabled = canAddPlayers;
    [addPlayersButton setTitle:(canAddPlayers ? @"Add Players" : @"Full") forState:UIControlStateNormal];
}

- (void)addPlayerToSession:(GKPlayer *)player {
    DDLog(@"player=%@", player);
    
    [self setStatus:[NSString stringWithFormat:@"%@ connected", player.alias]];
    
    NSDictionary *ps = [self playerStatusFromID:player.playerID];
    
    if (ps != nil) {
        [ps setValue:kGCPingStatusConnected forKey:kGCPingPlayerStatusKeyStatus];
    }
    else {
        [_playerStatus addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  player.playerID, kGCPingPlayerStatusKeyID,
                                  player.alias, kGCPingPlayerStatusKeyName,
                                  kGCPingStatusConnected, kGCPingPlayerStatusKeyStatus,
                                  nil]];
    }

    [playerStatusTableView reloadData];

    if (_match.expectedPlayerCount == 0) {
        [self showGameReady];
    }
    
    [self updateAddPlayersButton];
}

- (void)removePlayerFromSession:(NSString *)playerID {
    DDLog(@"playerID=%@", playerID);

    NSDictionary *ps = [self playerStatusFromID:playerID];
    if (ps) {
        [self showDisconnected:[ps objectForKey:kGCPingPlayerStatusKeyName]];
        [_playerStatus removeObject:ps];
        [playerStatusTableView reloadData];
    }
    else {
        // Do not show playerIDs to user, but debug that this player didn't connect due to network reasons
        DDLog(@"Player failed to connect: %@", playerID);
    }

    [self updateAddPlayersButton];
}

- (void)handlePingCommand:(NSString *)playerID withParams:(NSDictionary *)params {
    DDLog(@"playerID=%@, params=%@", playerID, params);

    [self updateStatus:@"Pinged Me" forPlayerID:playerID];
    [self sendPongToPlayer:playerID withParams:params];
    [self showPinged];
}

- (NSTimeInterval)calculateRTT:(NSTimeInterval)timeSent {
    return ([NSDate timeIntervalSinceReferenceDate] - timeSent);
}

- (void)handlePongCommand:(NSString *)playerID withParams:(NSDictionary *)params {
    DDLog(@"playerID=%@, params=%@", playerID, params);

    NSNumber *val = [params objectForKey:kGCPingMessageKeyTimeSent];
    NSAssert(val, @"No value for key kGCPingMessageKeyTimeSent");

    long rtt = (long)([self calculateRTT:(NSTimeInterval)[val doubleValue]] * 1000L);

    NSString *fmt = [NSString stringWithFormat:@"Ponged Me (%ld ms)", rtt];
    [self updateStatus:fmt forPlayerID:playerID];
    [playerStatusTableView reloadData];
}

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID {
    DDLog(@"match=%@, player=%@", match, playerID);
    
    NSDictionary *message = [self messageFromData:data];
    GCPingCommand cmd = [self commandFromMessage:message];
    if (cmd != kGCPingCommandUnknown) {
        NSDictionary *params = [self paramsFromMessage:message];
        if (cmd == kGCPingCommandPing) {
            [self handlePingCommand:playerID withParams:params];
        } else if (cmd == kGCPingCommandPong) {
            [self handlePongCommand:playerID withParams:params];
        }
    }
}

- (void)playerFromID:(NSString *)playerID withHandler:(void(^)(GKPlayer *))completionHandler {
    [GKPlayer loadPlayersForIdentifiers:[NSArray arrayWithObject:playerID]
                  withCompletionHandler:^(NSArray *players, NSError *error) {
                      if (error != nil) {
                          [self showError:error];
                      }
                      else {
                          completionHandler([players objectAtIndex:0]);
                      }
                  }];
}

- (void)match:(GKMatch *)match player:(NSString *)playerID didChangeState:(GKPlayerConnectionState)state {
    switch (state) {
        case GKPlayerStateConnected:
            DDLog(@"+++ %@ connected", playerID);
            [self playerFromID:playerID withHandler:^(GKPlayer *player) {
                [self addPlayerToSession:player];
            }];
            break;
        case GKPlayerStateDisconnected:
            DDLog(@"--- %@ disconnected", playerID);
            [self removePlayerFromSession:playerID];
            break;
        default:
            break;
    }
}

#pragma mark -
#pragma mark IBActions

- (IBAction)pingButtonPressed:(id)sender {
    DDLog(@"");
    
    [self sendPingToAllPlayers];
}

- (IBAction)addPlayersButtonPressed:(id)sender {
    DDLog(@"");

    // Add more players to session
    GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
    request.minPlayers = 2;
    request.maxPlayers = 4;
    [addPlayersButton setTitle:@"Searching..." forState:UIControlStateNormal];

    [[GKMatchmaker sharedMatchmaker] addPlayersToMatch:_match matchRequest:request completionHandler:^(NSError *error) {
        if (error != nil) {
            [self showError:error];
            [addPlayersButton setTitle:@"Add Players" forState:UIControlStateNormal];
        }
    }];
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
    [self setStatus:@"Game Ready"];
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

- (void)showErrorMessage:(NSString *)errorMessage {
    DDLog(@"errorMessage=%@", errorMessage);
    
    self.alertView = [[[UIAlertView alloc] initWithTitle:@"Error" 
                                                 message:errorMessage
                                                delegate:self 
                                       cancelButtonTitle:@"Cancel"
                                       otherButtonTitles:@"Disconnect", nil] autorelease];
    _alertView.tag = kConfirmDisconnectTag;
    [_alertView show];
    
}

- (void)showError:(NSError *)error {
    [self showErrorMessage:[error localizedDescription]];
}

#pragma mark -
#pragma mark UITableViewDelegate

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _playerStatus.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PlayerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSDictionary *playerStatus = [_playerStatus objectAtIndex:[indexPath row]];
    cell.textLabel.text = [playerStatus objectForKey:kGCPingPlayerStatusKeyName];
    cell.detailTextLabel.text = [playerStatus objectForKey:kGCPingPlayerStatusKeyStatus];
    return cell;
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
            if ([_match.playerIDs count] == 0) {
                [self sessionDisconnected];
            }
            break;
        default:
            break;
    }
}

@end

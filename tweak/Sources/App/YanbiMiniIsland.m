// Yanbi Now Playing overlay: a non-key, touch-through window in Spotify's scene.
// On an iPhone with a notch the capsule sits BELOW the protected status area.
// On Dynamic Island devices ActivityKit owns the hardware island; do not draw over it.
// The overlay is rendered in app screenshots but cannot cover SpringBoard or other apps.
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "Core/SGCore.h"
#import "Shared/Player/PlayerState.h"
#import "YanbiMiniIsland.h"

@interface SGYanbiIslandCoordinator : NSObject <SGPlayerStateObserver>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *capsule;
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UILabel *eyebrow;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *artist;
@property (nonatomic, strong) UIImageView *stateIcon;
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, copy) NSString *lastArtworkID;
@property (nonatomic) BOOL active;
+ (instancetype)shared;
- (void)start;
- (void)refresh;
- (void)layoutIn:(UIView *)root;
@end

@interface SGYanbiPassThroughWindow : UIWindow
@end
@implementation SGYanbiPassThroughWindow
// Never steal taps, scrolls, the keyboard, or the key window from Spotify.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    (void)point;
    (void)event;
    return nil;
}
@end

@interface SGYanbiOverlayController : UIViewController
@end
@implementation SGYanbiOverlayController
- (void)loadView {
    UIView *view = [UIView new];
    view.backgroundColor = UIColor.clearColor;
    view.userInteractionEnabled = NO;
    self.view = view;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [[SGYanbiIslandCoordinator shared] layoutIn:self.view];
}
@end

@implementation SGYanbiIslandCoordinator

+ (instancetype)shared {
    static SGYanbiIslandCoordinator *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [SGYanbiIslandCoordinator new]; });
    return manager;
}

- (void)start {
    if (self.active) return;
    self.active = YES;
    SGAddPlayerStateObserver(self);
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(refresh) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(hide) name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(refresh) name:UISceneDidActivateNotification object:nil];
    [center addObserver:self selector:@selector(refresh) name:UIDeviceOrientationDidChangeNotification object:nil];
    [self refresh];
}

- (UIWindowScene *)foregroundScene {
    UIApplication *application = UIApplication.sharedApplication;
    if (application.applicationState != UIApplicationStateActive) return nil;
    UIWindowScene *first = nil;
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive)
            continue;
        UIWindowScene *candidate = (UIWindowScene *)scene;
        if (!first) first = candidate;
        for (UIWindow *window in candidate.windows) {
            if (window.isKeyWindow && window != self.window) return candidate;
        }
    }
    return first;
}

- (void)hide {
    self.window.hidden = YES;
}

- (void)refresh {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }
    if (!SGFlag(SGKeyYanbiMiniIsland, YES) || UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone) {
        [self hide];
        return;
    }
    UIWindowScene *scene = [self foregroundScene];
    if (!scene) {
        [self hide];
        return;
    }
    if (self.window.windowScene != scene) {
        self.window.hidden = YES;
        self.window = nil;
        [self createWindowInScene:scene];
    }
    [self updateMusic:SGPlayerState()];
    self.window.hidden = NO;
    [self layoutIn:self.window.rootViewController.view];
}

- (void)createWindowInScene:(UIWindowScene *)scene {
    SGYanbiPassThroughWindow *window = [[SGYanbiPassThroughWindow alloc] initWithWindowScene:scene];
    window.frame = scene.coordinateSpace.bounds;
    window.windowLevel = UIWindowLevelNormal + 5;
    window.backgroundColor = UIColor.clearColor;
    SGYanbiOverlayController *controller = [SGYanbiOverlayController new];
    window.rootViewController = controller;
    window.userInteractionEnabled = NO;

    UIView *pill = [UIView new];
    pill.backgroundColor = [UIColor colorWithRed:0.055 green:0.066 blue:0.066 alpha:0.98];
    pill.layer.cornerRadius = 23;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.borderWidth = 0.8;
    pill.layer.borderColor = [UIColor colorWithRed:0.35 green:0.93 blue:0.60 alpha:0.52].CGColor;
    pill.layer.shadowColor = [UIColor colorWithRed:0.25 green:0.78 blue:0.54 alpha:1].CGColor;
    pill.layer.shadowOpacity = 0.18;
    pill.layer.shadowRadius = 10;
    pill.layer.shadowOffset = CGSizeMake(0, 3);
    [controller.view addSubview:pill];
    self.capsule = pill;

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[(id)[UIColor colorWithRed:0.11 green:0.18 blue:0.15 alpha:1].CGColor,
                        (id)[UIColor colorWithRed:0.055 green:0.060 blue:0.067 alpha:1].CGColor];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    gradient.cornerRadius = 23;
    [pill.layer insertSublayer:gradient atIndex:0];
    self.gradient = gradient;

    UIImageView *art = [UIImageView new];
    art.contentMode = UIViewContentModeScaleAspectFill;
    art.layer.cornerRadius = 10;
    art.clipsToBounds = YES;
    art.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
    art.tintColor = UIColor.whiteColor;
    [pill addSubview:art];
    self.artwork = art;
    NSString *portrait = [NSBundle.mainBundle pathForResource:@"yanbi-avatar" ofType:@"jpg"];
    if (portrait.length) art.image = [UIImage imageWithContentsOfFile:portrait];
    if (!art.image) art.image = [UIImage systemImageNamed:@"music.note"];

    UILabel *eyebrow = [UILabel new];
    eyebrow.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
    eyebrow.textColor = [UIColor colorWithRed:0.38 green:0.96 blue:0.61 alpha:1];
    eyebrow.text = @"developer yanbi · Spotify";
    eyebrow.lineBreakMode = NSLineBreakByTruncatingTail;
    [pill addSubview:eyebrow];
    self.eyebrow = eyebrow;

    UILabel *title = [UILabel new];
    title.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    title.textColor = UIColor.whiteColor;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    [pill addSubview:title];
    self.title = title;

    UILabel *artist = [UILabel new];
    artist.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
    artist.textColor = [UIColor colorWithWhite:0.71 alpha:1];
    artist.lineBreakMode = NSLineBreakByTruncatingTail;
    [pill addSubview:artist];
    self.artist = artist;

    UIImageView *symbol = [UIImageView new];
    symbol.tintColor = [UIColor colorWithRed:0.41 green:0.95 blue:0.61 alpha:1];
    symbol.contentMode = UIViewContentModeCenter;
    [pill addSubview:symbol];
    self.stateIcon = symbol;
    self.window = window;
}

- (void)layoutIn:(UIView *)root {
    if (!root || !self.capsule) return;
    UIWindowScene *scene = self.window.windowScene;
    CGFloat w = CGRectGetWidth(root.bounds);
    CGFloat h = CGRectGetHeight(root.bounds);
    CGFloat top = MAX(root.safeAreaInsets.top, self.window.safeAreaInsets.top);
    BOOL portrait = scene && UIInterfaceOrientationIsPortrait(scene.interfaceOrientation);
    // Dynamic Island iPhones have a taller safe area. Prefer native ActivityKit on them.
    BOOL systemIsland = top >= 54;
    BOOL notch = top >= 35 && top < 54;
    BOOL show = notch && portrait && w >= 320 && h >= 550 && SGFlag(SGKeyYanbiMiniIsland, YES);
    self.capsule.hidden = !show;
    if (!show) return;
    CGFloat width = MIN(w - 44, 296);
    CGFloat height = 57;
    // Just BELOW the camera/status-bar reserved area: this never draws over system privacy indicators.
    CGFloat y = top + 3;
    self.capsule.frame = CGRectMake(round((w - width) / 2), y, width, height);
    self.gradient.frame = self.capsule.bounds;
    self.artwork.frame = CGRectMake(9, 10, 37, 37);
    CGFloat x = 54;
    CGFloat textWidth = MAX(40, width - x - 39);
    self.eyebrow.frame = CGRectMake(x, 6, textWidth, 13);
    self.title.frame = CGRectMake(x, 19, textWidth, 21);
    self.artist.frame = CGRectMake(x, 39, textWidth, 13);
    self.stateIcon.frame = CGRectMake(width - 35, 17, 27, 24);
    (void)systemIsland;
}

- (void)updateMusic:(SPTPlayerState *)state {
    NSString *song = state.track.trackTitle;
    BOOL playing = song.length && !state.isPaused;
    NSString *artist = state.track.artistName;
    self.eyebrow.text = playing ? @"developer yanbi · đang phát" :
                        song.length ? @"developer yanbi · tạm dừng" : @"developer yanbi · Spotify";
    self.title.text = song.length ? song : @"Sẵn sàng phát nhạc";
    self.artist.text = artist.length ? artist : @"Mở nhạc để bắt đầu";
    UIImageSymbolConfiguration *style = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    self.stateIcon.image = [UIImage systemImageNamed:playing ? @"waveform" : song.length ? @"pause.fill" : @"music.note"
                                  withConfiguration:style];

    NSString *trackID = state.track.URI ? [state.track.URI description] : song;
    if ([self.lastArtworkID isEqualToString:trackID]) return;
    self.lastArtworkID = [trackID copy];
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    NSString *nowTitle = info[MPMediaItemPropertyTitle];
    MPMediaItemArtwork *cover = [nowTitle isEqualToString:song] ? info[MPMediaItemPropertyArtwork] : nil;
    UIImage *image = [cover isKindOfClass:MPMediaItemArtwork.class] ? [cover imageWithSize:CGSizeMake(64, 64)] : nil;
    if (!image) {
        NSString *portrait = [NSBundle.mainBundle pathForResource:@"yanbi-avatar" ofType:@"jpg"];
        image = portrait.length ? [UIImage imageWithContentsOfFile:portrait] : nil;
    }
    self.artwork.image = image ?: [UIImage systemImageNamed:@"music.note"];
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self playerStateDidChange:state]; });
        return;
    }
    if (!self.window || self.window.isHidden) return;
    [self updateMusic:state];
}
@end

void SGYanbiIslandInstall(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ SGYanbiIslandInstall(); });
        return;
    }
    [[SGYanbiIslandCoordinator shared] start];
}
void SGYanbiIslandRefresh(void) {
    [[SGYanbiIslandCoordinator shared] refresh];
}

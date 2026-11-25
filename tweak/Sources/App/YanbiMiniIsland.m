// Yanbi Now Playing overlay: a non-key, touch-through window in Spotify's scene.
// A black, top-aligned app overlay on notch devices; not the actual hardware notch.
// On Dynamic Island devices ActivityKit owns the hardware island; do not draw over it.
// The overlay is rendered in app screenshots but cannot cover SpringBoard or other apps.
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <sys/utsname.h>

// Model classification only. Width is an artistic approximation of the supplied screenshot,
// not a private hardware cutout measurement (UIKit exposes no cutout rectangle).
static NSInteger SGYanbiCutoutKind(CGFloat top) {
    static NSString *model;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ struct utsname u; if (uname(&u) == 0) model = [NSString stringWithUTF8String:u.machine]; });
    static NSSet<NSString *> *wide, *narrow, *flat;
    static dispatch_once_t profiles;
    dispatch_once(&profiles, ^{
        wide = [NSSet setWithArray:@[@"iPhone10,3",@"iPhone10,6",@"iPhone11,2",@"iPhone11,4",@"iPhone11,6",@"iPhone11,8",@"iPhone12,1",@"iPhone12,3",@"iPhone12,5",@"iPhone13,1",@"iPhone13,2",@"iPhone13,3",@"iPhone13,4"]];
        narrow = [NSSet setWithArray:@[@"iPhone14,2",@"iPhone14,3",@"iPhone14,4",@"iPhone14,5",@"iPhone14,7",@"iPhone14,8",@"iPhone17,5"]];
        flat = [NSSet setWithArray:@[@"iPhone10,1",@"iPhone10,2",@"iPhone10,4",@"iPhone10,5",@"iPhone12,8",@"iPhone14,6"]];
    });
    if ([wide containsObject:model ?: @""]) return 1;
    if ([narrow containsObject:model ?: @""]) return 2;
    if ([flat containsObject:model ?: @""]) return 0;
    // Unknown models: keep the system island or hide rather than assume physical geometry.
    return top >= 54 ? 3 : top >= 38 ? 2 : 0;
}
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
@property (nonatomic, strong) UIImage *portrait;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL stateKnown;
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
    if (portrait.length) self.portrait = [UIImage imageWithContentsOfFile:portrait];
    art.image = self.portrait;
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
    self.lastArtworkID = nil;
    self.stateKnown = NO;
    self.window = window;
}

- (void)layoutIn:(UIView *)root {
    if (!root || !self.capsule) return;
    UIWindowScene *scene = self.window.windowScene;
    CGFloat w = CGRectGetWidth(root.bounds);
    CGFloat h = CGRectGetHeight(root.bounds);
    CGFloat top = MAX(root.safeAreaInsets.top, self.window.safeAreaInsets.top);
    BOOL portrait = scene && UIInterfaceOrientationIsPortrait(scene.interfaceOrientation);
    // Read insets from the main app window as well; the overlay may initially report zero.
    for (UIWindow *candidate in scene.windows) {
        if (candidate != self.window && candidate.isKeyWindow) {
            top = MAX(top, candidate.safeAreaInsets.top);
            break;
        }
    }
    NSInteger kind = SGYanbiCutoutKind(top);
    BOOL show = (kind == 1 || kind == 2) && top >= 38 && top < 54 && portrait && w >= 320 && h >= 550 && SGFlag(SGKeyYanbiMiniIsland, YES);
    self.capsule.hidden = !show;
    if (!show) return;
    CGFloat pixel = MAX(1.0, scene.screen.scale);
    CGFloat width = floor(MIN(w * (kind == 1 ? 0.55 : 0.46), w - 164) * pixel) / pixel;
    CGFloat height = MIN(32, top - 5);
    // Black app-rendered silhouette, flush with the top edge as in the reference.
    // Side status indicators remain under system control. Exact hardware shape is not exposed.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.capsule.frame = CGRectMake(round((w - width) * pixel / 2) / pixel, 0, width, height);
    self.capsule.backgroundColor = UIColor.blackColor;
    self.capsule.layer.cornerRadius = MIN(19, height * 0.6);
    self.capsule.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    self.capsule.layer.borderWidth = 0;
    self.capsule.layer.shadowOpacity = 0;
    self.gradient.hidden = YES;
    self.artwork.frame = CGRectMake(12, 4, 24, 24);
    self.artwork.layer.cornerRadius = 12;
    self.eyebrow.frame = CGRectMake(42, 2, MAX(20, width - 70), 12);
    self.title.frame = CGRectMake(42, 13, MAX(20, width - 70), 16);
    self.title.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    self.artist.hidden = YES;
    self.stateIcon.frame = CGRectMake(width - 25, 6, 18, 20);
    [CATransaction commit];
}

- (void)updateMusic:(SPTPlayerState *)state {
    NSString *song = state.track.trackTitle;
    BOOL playing = song.length && state.isPlaying && !state.isPaused;
    BOOL changed = !self.stateKnown || self.playing != playing;
    self.stateKnown = YES;
    self.playing = playing;
    NSString *artist = state.track.artistName;
    self.eyebrow.text = @"developer yanbi";
    self.title.text = song.length ? song : @"Sẵn sàng phát nhạc";
    self.artist.text = artist.length ? artist : @"Mở nhạc để bắt đầu";
    UIImageSymbolConfiguration *style = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightBold];
    self.stateIcon.image = [UIImage systemImageNamed:playing ? @"waveform" : song.length ? @"pause.fill" : @"music.note"
                                  withConfiguration:style];

    if (changed && !UIAccessibilityIsReduceMotionEnabled()) {
        CATransition *fade = [CATransition animation];
        fade.type = kCATransitionFade; fade.duration = 0.18;
        [self.stateIcon.layer addAnimation:fade forKey:@"yanbi-state"];
    }
    NSString *trackID = state.track.URI ? [state.track.URI description] : song;
    if ([self.lastArtworkID isEqualToString:trackID]) return;
    self.lastArtworkID = [trackID copy];
    // Preserve the developer portrait; never substitute a low-resolution album thumbnail.
    self.artwork.image = self.portrait ?: [UIImage systemImageNamed:@"music.note"];
    if (!UIAccessibilityIsReduceMotionEnabled()) {
        CATransition *fade = [CATransition animation];
        fade.type = kCATransitionFade; fade.duration = 0.2;
        [self.title.layer addAnimation:fade forKey:@"yanbi-track"];
    }
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

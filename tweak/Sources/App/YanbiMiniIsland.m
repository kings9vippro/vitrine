// An in-app miniature now-playing island for devices without system Dynamic Island.
// It is deliberately confined to the Vitrine settings page's table header. No status-bar
// hooks, private microphone/camera monitoring, additional window or background polling.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/SGCore.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Headers/SPTPlayer.h"
#import "YanbiMiniIsland.h"

@interface SGYanbiMiniIslandView ()
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIImageView *art;
@property (nonatomic, strong) UILabel *eyebrow;
@property (nonatomic, strong) UILabel *song;
@property (nonatomic, strong) UILabel *artist;
@property (nonatomic, strong) UIButton *play;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *artTrack;
@end

@implementation SGYanbiMiniIslandView

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;

    _pill = [UIView new];
    _pill.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.97];
    _pill.layer.cornerRadius = 28;
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    _pill.layer.borderWidth = 0.7;
    _pill.layer.borderColor = [UIColor colorWithRed:0.26 green:0.85 blue:0.58 alpha:0.32].CGColor;
    _pill.layer.masksToBounds = YES;
    [self addSubview:_pill];

    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blur.userInteractionEnabled = NO;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.frame = CGRectMake(0, 0, 100, 64);
    [_pill addSubview:blur];

    _art = [UIImageView new];
    _art.contentMode = UIViewContentModeScaleAspectFill;
    _art.clipsToBounds = YES;
    _art.layer.cornerRadius = 10;
    _art.backgroundColor = [UIColor colorWithWhite:0.17 alpha:1];
    _art.tintColor = UIColor.whiteColor;
    [_pill addSubview:_art];

    _eyebrow = [UILabel new];
    _eyebrow.text = @"developer yanbi  •  đang phát";
    _eyebrow.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    _eyebrow.textColor = [UIColor colorWithRed:0.43 green:0.98 blue:0.65 alpha:1];
    _eyebrow.numberOfLines = 1;
    [_pill addSubview:_eyebrow];

    _song = [UILabel new];
    _song.text = @"Spotify";
    _song.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _song.textColor = UIColor.whiteColor;
    _song.numberOfLines = 1;
    _song.adjustsFontSizeToFitWidth = YES;
    _song.minimumScaleFactor = 0.78;
    [_pill addSubview:_song];

    _artist = [UILabel new];
    _artist.text = @"Đang kiểm tra bài hát";
    _artist.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _artist.textColor = [UIColor colorWithWhite:0.78 alpha:1];
    _artist.numberOfLines = 1;
    [_pill addSubview:_artist];

    _play = [UIButton buttonWithType:UIButtonTypeSystem];
    _play.tintColor = UIColor.whiteColor;
    _play.accessibilityLabel = @"Phát hoặc tạm dừng bài hát";
    [_play addTarget:self action:@selector(togglePlayback) forControlEvents:UIControlEventTouchUpInside];
    [_pill addSubview:_play];
    [self updateNowPlaying];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect full = self.bounds;
    CGFloat horizontal = 20;
    CGFloat width = MAX(0, CGRectGetWidth(full) - 2 * horizontal);
    _pill.frame = CGRectMake(horizontal, 9, width, 66);
    _art.frame = CGRectMake(12, 12, 42, 42);
    CGFloat buttonWidth = 42;
    _play.frame = CGRectMake(width - buttonWidth - 8, 11, buttonWidth, 44);
    CGFloat contentX = 66;
    CGFloat contentWidth = MAX(10, width - contentX - buttonWidth - 16);
    _eyebrow.frame = CGRectMake(contentX, 8, contentWidth, 13);
    _song.frame = CGRectMake(contentX, 22, contentWidth, 22);
    _artist.frame = CGRectMake(contentX, 46, contentWidth, 13);
}

- (void)setActive:(BOOL)active {
    if (!active) {
        [_timer invalidate];
        _timer = nil;
        return;
    }
    [self updateNowPlaying];
    if (_timer) return;
    _timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(updateNowPlaying) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)updateNowPlaying {
    // This is Spotify's own player state, just like Shared/LiveActivity/LiveActivity.x.
    id<SPTPlayer> player = SGKaraokePlayer();
    SPTPlayerState *state = player.state;
    NSString *title = state.track.trackTitle;
    BOOL hasTrack = title.length > 0;
    BOOL paused = hasTrack && state.isPaused;
    _eyebrow.text = hasTrack ? (paused ? @"developer yanbi  •  tạm dừng" : @"developer yanbi  •  đang phát")
                             : @"developer yanbi  •  Spotify";
    _song.text = hasTrack ? title : @"Chưa có bài hát đang phát";
    _artist.text = hasTrack ? (state.track.artistName ?: @"") : @"Mở nhạc để theo dõi tại đây";
    _play.hidden = !hasTrack;
    UIImageSymbolConfiguration *symbol = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
    UIImage *control = [UIImage systemImageNamed:paused ? @"play.fill" : @"pause.fill" withConfiguration:symbol];
    [_play setImage:control forState:UIControlStateNormal];
    _play.accessibilityLabel = paused ? @"Tiếp tục phát nhạc" : @"Tạm dừng nhạc";
    if (!hasTrack) {
        _artTrack = nil;
        _art.contentMode = UIViewContentModeCenter;
        _art.image = [UIImage systemImageNamed:@"music.note"];
        return;
    }

    // Do not decode album artwork each second. Only update once the track changes.
    if ([_artTrack isEqualToString:title]) return;
    _artTrack = [title copy];
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    if (![info[MPMediaItemPropertyTitle] isEqualToString:title]) info = nil;
    MPMediaItemArtwork *artwork = info[MPMediaItemPropertyArtwork];
    UIImage *cover = [artwork isKindOfClass:MPMediaItemArtwork.class] ? [artwork imageWithSize:CGSizeMake(60, 60)] : nil;
    _art.contentMode = cover ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
    _art.image = cover ?: [UIImage systemImageNamed:@"music.note"];
}

- (void)togglePlayback {
    id<SPTPlayer> player = SGKaraokePlayer();
    if (!player.state.track.trackTitle.length) return;
    if (player.state.isPaused) [player resume:nil];
    else [player pause:nil];
    [self updateNowPlaying];
}

- (void)dealloc {
    [_timer invalidate];
}

@end

// The Live Activity page (App/ModSettings.x links it from the root, under either look): the preview at its top
// (SGLiveActivityPreview.m), then the switch, the view and the card's options, which the tick reads, so they
// apply at once to a card that is showing.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Shared/Player/SleepTimer.h"
#import "LiveActivity.h"
#import "SGLiveActivityPreview.h"

static NSArray<NSString *> *viewNames(void) {
    return @[@"Lời bài hát", @"Hàng chờ", @"Điều khiển"];
}

@interface SGLiveActivityPage : SGModPage
@property (nonatomic, strong) SGLiveActivityPreview *preview;
@end

@implementation SGLiveActivityPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView = self.preview;
}

// Handed back to the table only when its size changes (SGFitNote's way: the table lays out again on every handing back).
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width;
    self.preview.layoutMargins = UIEdgeInsetsMake(0, table.layoutMargins.left, 0, table.layoutMargins.right);
    CGSize size = CGSizeMake(width, [self.preview heightForWidth:width]);
    if (CGSizeEqualToSize(self.preview.bounds.size, size)) return;
    self.preview.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = self.preview;
}

// Back from Shows' or Text size's list, the preview reads them again.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.preview reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.preview.running = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.preview.running = NO;
}

@end

// A menu row of `names` stored under `key`, which shows the preview the new choice.
static SGModRow *menuRow(NSString *title, NSString *key, NSArray<NSString *> *names, NSInteger fallback, SGLiveActivityPreview *preview) {
    __weak SGLiveActivityPreview *weakPreview = preview;
    return SGMenuRow(title, names, ^NSString *{
        NSInteger index = SGInt(key, fallback);
        return names[(NSUInteger)(index >= 0 && index < (NSInteger)names.count ? index : fallback)];
    }, ^(NSInteger index) {
        SGSetInt(key, index);
        [weakPreview reload];
    });
}

BOOL SGLiveActivityAllowedByInstall(void) {
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSSupportsLiveActivities"] boolValue];
}

// At the top while the install lacks the key, saying why nothing shows and what to do.
static SGModRow *missingRow(void) {
    SGModRow *row = SGWarningRow(@"Thiếu tiện ích trong bản cài", @"Xem nguyên nhân", ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa có Hoạt động trực tiếp"
            message:@"iOS chỉ hiển thị Hoạt động trực tiếp khi ứng dụng khai báo hỗ trợ. Hãy đóng gói IPA bằng workflow Vitrine để thêm tiện ích Dynamic Island và màn hình khóa."
            preferredStyle:UIAlertControllerStyleAlert];
        alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
    });
    row.visible = ^BOOL { return !SGLiveActivityAllowedByInstall(); };
    return row;
}

UIViewController *SGLiveActivitySettingsPage(void) {
    SGLiveActivityPreview *preview = [SGLiveActivityPreview new];
    __weak SGLiveActivityPreview *weakPreview = preview;
    void (^switched)(BOOL) = ^(BOOL on) { [weakPreview reload]; };

    SGModRow *on = SGSwitchRow(@"Lời nhạc trực tiếp", @"Hiển thị trên màn hình khóa và Dynamic Island (máy tương thích)", SGKeyLiveActivity);
    on.changed = ^(BOOL value) { SGSetLiveActivityEnabled(value); };
    SGModRow *view = SGChoiceRow(@"Hiển thị", nil, SGKeyLiveActivityView, viewNames(), SGLiveActivityLyrics);
    // The lyrics view's own rows, shown while it is picked.
    SGModRow *without = menuRow(@"Khi không có lời", SGKeyLiveActivityWithoutLyrics, @[@"Nốt nhạc", @"Tên bài hát"], SGLiveActivityWithoutLyricsTrack, preview);
    SGModRow *alignment = menuRow(@"Căn chỉnh", SGKeyLiveActivityAlignment, @[@"Trái", @"Giữa"], SGLiveActivityAlignCenter, preview);
    SGModRow *translation = SGOptionRow(@"Bản dịch", @"Hiện bản dịch ngay dưới lời bài hát", SGKeyLiveActivityTranslation);
    translation.changed = switched;
    SGModRow *size = SGChoiceRow(@"Cỡ chữ", nil, SGKeyLiveActivityTextSize, @[@"Nhỏ", @"Vừa", @"Lớn"], SGLiveActivityTextMedium);
    for (SGModRow *row in @[without, alignment, translation, size]) row.visible = ^BOOL { return SGInt(SGKeyLiveActivityView, SGLiveActivityLyrics) == SGLiveActivityLyrics; };
    // Every view's.
    SGModRow *artwork = SGSwitchRow(@"Ảnh bìa", @"Hiện ảnh bìa trong Dynamic Island", SGKeyLiveActivityArtwork);
    artwork.changed = switched;
    SGModRow *colors = menuRow(@"Màu sắc", SGKeyLiveActivityColors, @[@"Spotify", @"Theo ảnh bìa", @"Tối giản"], SGLiveActivityColorsSpotify, preview);
    SGModRow *progress = SGSwitchRow(@"Thanh tiến trình", nil, SGKeyLiveActivityProgressBar);
    progress.changed = switched;
    // The sleep timer's own: the card's Timer tab, the Sleep Timer shortcut and its control all fade by it, card on or
    // off, and so does Spotify's own timer from the player's menu (Shared/Player/SpotifySleepTimer.m).
    NSArray<NSString *> *fades = SGSleepTimerFadeNames();
    SGModRow *fade = SGMenuRow(@"Giảm âm từ từ", fades, ^NSString *{ return fades[(NSUInteger)SGSleepTimerFadeChoice()]; },
                               ^(NSInteger index) { SGSetInt(SGKeySleepTimerFade, index); });
    SGLiveActivityPage *page = [[SGLiveActivityPage alloc] initWithTitle:@"Lời nhạc trực tiếp" intro:nil sections:@[
        SGSection(nil, @[missingRow(), on, view, without, alignment, translation, size]),
        SGNotedSection(@"Thẻ hiển thị", @[artwork, colors, progress],
                       @"Spotify dùng sắc xanh đặc trưng; Theo ảnh bìa sử dụng màu của bài hát; "
                       @"Tối giản dùng chữ trắng trên nền hệ thống. "
                       @"Thông tin cũng có thể xuất hiện trên Apple Watch (từ iOS 18) và CarPlay (từ iOS 26). "
                       @"Chạm vào thẻ sẽ mở Spotify nếu App ID ký IPA khớp Bundle ID. Trên iPhone tai thỏ, hoạt động này hiển thị ở màn hình khóa; đảo nhạc mini riêng chỉ xuất hiện bên trong trang Vitrine."),
        SGNotedSection(@"Hẹn giờ tắt nhạc", @[fade],
                       @"Điều chỉnh cách âm lượng giảm dần trước khi hẹn giờ tạm dừng Spotify. Áp dụng cho cả hẹn giờ trong ứng dụng và phím tắt."),
    ] footer:nil];
    page.preview = preview;
    return page;
}

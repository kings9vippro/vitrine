#import "Core/SGCore.h"
#import "Shared/AppIcon/AppIcon.h"
#import "Shared/Fonts/Fonts.h"
#import "Shared/LyricsTranslation/LyricsTranslation.h"
#import "Redesigned/Player/Player.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Pages.h"
#import "Shared/ArtistBlock/ArtistBlock.h"
#import "Shared/Gestures/Gestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LyricsMeanings/Meanings.h"
#import "Shared/Player/PlayerSettings.h"
#import "Shared/Sing/Sing.h"
#import "Native/Appearance/Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Native/NowPlayingBar/NowPlayingBar.h"
#import "Native/Player/NowPlaying.h"
#import "Shared/LiveActivity/LiveActivity.h"
#import "Shared/Lossless/SGLossless.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Lyrics/LyricsLook.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Redesigned/Kit/SGRAccent.h"

NSString *const SGRedesignedUIInfo = @"Giao diện mới của Vitrine lấy cảm hứng từ Apple Music. Tùy chỉnh của chế độ cũ có thể không tương thích.\n\nGiao diện gốc linh hoạt hơn và vẫn giữ phong cách Spotify.";

// Below iOS 26 the redesign also needs SGKeyRedesignUntested (Core/SGUIMode.h): whoever calls this has
// shown the warning. Turning it off takes that back, so turning it on again warns again.
void SGSetRedesignedUI(BOOL on) {
    SGSetEnabled(SGKeyRedesign, on);
    SGSetEnabled(SGKeyRedesignUntested, on && !SGRedesignAvailable());
}

NSString *SGRedesignUntestedWarning(void) {
    return [NSString stringWithFormat:@"Giao diện Liquid Glass được thiết kế cho iOS 26. Trên iOS %@, hệ thống chỉ hiển thị hiệu ứng mờ thay thế; bố cục có thể lỗi hoặc Spotify có thể treo khi mở. Nếu không khởi động được, lần mở tiếp theo sẽ trở về giao diện gốc.",
            UIDevice.currentDevice.systemVersion];
}

// The whole look changes hands at launch, so the switch asks for the restart straight away rather than
// leaving Spotify half in the old look.
static void offerRestart(BOOL on) {
    SGOfferRestart(on ? @"Giao diện mới sẽ áp dụng sau khi Spotify khởi động lại. Ứng dụng sẽ đóng; hãy mở lại để xem."
                      : @"Giao diện Spotify gốc sẽ trở lại sau khi khởi động lại. Ứng dụng sẽ đóng; hãy mở lại để xem.");
}

// Below iOS 26 the switch stores the warning's key, not the look's: it is on only once the warning has
// been accepted, which restarts Spotify at once, so the switch never reads on for a look that is not coming.
static SGModRow *untestedRow(void) {
    SGModRow *row = SGOptionRow(@"Giao diện thiết kế lại", [NSString stringWithFormat:@"Chưa kiểm thử trên iOS %@", UIDevice.currentDevice.systemVersion], SGKeyRedesignUntested);
    row.glows = YES;
    row.info = SGRedesignedUIInfo;
    row.changed = ^(BOOL on) {
        if (!on) {
            SGSetRedesignedUI(NO);
            offerRestart(NO);
            return;
        }
        SGSetEnabled(SGKeyRedesignUntested, NO);   // the page reloads to off; the warning's button turns it on
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bật giao diện thiết kế lại?"
            message:[SGRedesignUntestedWarning() stringByAppendingString:@"\n\nSpotify sẽ khởi động lại để áp dụng."]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Bật và khởi động lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            SGSetRedesignedUI(YES);
            SGRestartSpotify();
        }]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
    };
    return SGWithTile(row, @"sparkles", UIColor.systemIndigoColor);
}

SGModRow *SGRedesignedUIRow(void) {
    if (!SGRedesignAvailable()) return untestedRow();
    SGModRow *redesign = SGOptionRow(@"Giao diện thiết kế lại", nil, SGKeyRedesign);
    redesign.glows = YES;
    redesign.info = SGRedesignedUIInfo;
    redesign.changed = ^(BOOL on) {
        SGSetRedesignedUI(on);
        offerRestart(on);
    };
    return SGWithTile(redesign, @"sparkles", UIColor.systemIndigoColor);
}

// The stored look's own rows, then the font and the app icon, which work under either look on any iOS.
// Redesigned UI itself leads Mod Settings' main page.
UIViewController *SGAppearancePage(void) {
    NSMutableArray<SGModRow *> *everywhere = [NSMutableArray arrayWithArray:SGAppFontRows()];
    SGModRow *icon = SGAppIconRow();
    if (icon) [everywhere addObject:icon];
    return [[SGModPage alloc] initWithTitle:@"Giao diện" intro:SGRestartNote sections:@[
        SGSection(nil, SGRedesignedUIStored() ? SGRAppearanceRows() : SGNativeAppearanceRows()),
        SGSection(nil, everywhere),
    ] footer:nil];
}

UIViewController *SGNavbarPage(void) {
    return SGRedesignedUIStored() ? SGRNavbarSettingsPage() : SGNavbarSettingsPage();
}

// Pronunciation, romanized lines, translation, word sweeping and line meanings exist only in the redesign's lyrics view.
static UIViewController *lyricsPage(void) {
    BOOL redesigned = SGRedesignedUIStored();
    NSMutableArray<SGModRow *> *more = [NSMutableArray arrayWithObjects:SGLockScreenLyricsRow(), SGLockScreenTranslationRow(), nil];
    if (!redesigned) [more insertObject:SGGlassLyricsRow() atIndex:0];
    SGModRow *sing = SGPageRow(@"Karaoke", ^UIViewController *{ return SGSingSettingsPage(); });
    sing.value = ^NSString *{ return SGSingSummary(); };
    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObjects:SGSection(nil, @[SGWithTile(sing, @"music.mic", UIColor.systemRedColor)]),
                                                SGLyricsSourcesSection(redesigned), nil];
    SGModSection *timing = SGNotedSection(@"Độ trễ lời bài hát", @[SGLyricsDelayRow()],
        @"Điều chỉnh độ trễ lời nhạc để đồng bộ với âm thanh, đặc biệt khi dùng tai nghe Bluetooth. Có hiệu lực ngay.");
    if (redesigned) {
        [sections addObjectsFromArray:@[
            SGSection(@"Hiển thị", @[SGRLyricsTextSizesRow(), SGLyricsWordTimingRow(), SGLyricsRomanisedRow(), SGLyricsRomanisedReplaceRow(),
                SGRLyricsHideRow(),
                SGSwitchRow(@"Lời nhạc màn hình ngang", @"Xoay ngang điện thoại khi đang mở lời nhạc", SGRKeyLyricsLandscape)]),
            timing,
            SGSection(@"Dịch lời bài hát", [[[@[SGLyricsTranslationLanguageRow(), SGTranslateEverySongRow()] arrayByAddingObjectsFromArray:SGOnDeviceTranslatorRows()]
                                          arrayByAddingObjectsFromArray:SGAITranslatorRows()] arrayByAddingObject:SGSavedTranslationsRow()]),
            SGSection(nil, @[SGLyricsMeaningsRow()]),
        ]];
    } else {
        [sections addObject:timing];
    }
    [sections addObject:SGSection(nil, more)];
    // The redesign's page leads with its lyrics playing in the look the page sets, and that look's presets.
    if (redesigned) return SGRLyricsSettingsPage(@"Lời bài hát", @"Giao diện thay đổi ngay. Các tùy chọn bên dưới có hiệu lực sau khi khởi động lại Spotify.", sections);
    return [[SGModPage alloc] initWithTitle:@"Lời bài hát" intro:SGRestartNote sections:sections footer:nil];
}

// Lyrics has its own row on Mod Settings' main page, beside Sing.
UIViewController *SGLyricsSettingsPage(void) {
    return lyricsPage();
}

UIViewController *SGPlayerSettingsPage(void) {
    SGModRow *blocked = SGPageRow(@"Nghệ sĩ đã chặn", ^UIViewController *{ return SGArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return SGFlag(SGKeyArtistBlock, NO) ? @(SGBlockedArtists().count).stringValue : @"Tắt";
    };
    BOOL native = !SGRedesignedUIStored();

    // AirPods gestures, the lock screen widget and Vibrations have rows of their own on Mod Settings' main page.
    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObject:SGSection(nil, @[
        SGWithTile(SGPageRow(@"Cử chỉ", ^UIViewController *{ return SGGesturesSettingsPage(); }), @"hand.tap", UIColor.systemBlueColor),
        SGWithTile(blocked, @"person.crop.circle.badge.xmark", UIColor.systemRedColor),
    ])];
    if (native) {
        [sections addObject:SGSection(nil, @[
            SGWithTile(SGPageRow(@"Thanh phát nhạc", ^UIViewController *{ return SGNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled", UIColor.systemPinkColor),
            SGWithTile(SGPageRow(@"Hàng chờ và thiết bị", ^UIViewController *{ return SGQueueSettingsPage(); }), @"text.line.first.and.arrowtriangle.forward", UIColor.systemIndigoColor),
        ])];
        [sections addObjectsFromArray:SGNativePlayerScreenSections()];
    }
    // Switch to video is the same chip of Spotify's player under either look.
    SGModRow *video = SGHideRow(@"Chuyển sang video", @"Nút video phía trên tên bài hát", SGKeyHideVideoSwitch);
    // Spotify's own, under either look: a tap on the cover opens it full screen, where it turns a little with the phone.
    SGModRow *tilt = SGHideRow(@"Ảnh bìa toàn màn hình", @"Tùy chọn mở ảnh bìa khi chạm vào", SGKeyHideFullScreenCover);
    // The native look's Shuffle and Repeat rows are in its Hide on the player section, with their own keys.
    NSArray<SGModRow *> *hidden = native ? @[video, tilt]
        : @[SGHideRow(@"Phát ngẫu nhiên", nil, SGRKeyPlayerHideShuffle), SGHideRow(@"Lặp lại", nil, SGRKeyPlayerHideRepeat), video, tilt];
    [sections addObject:SGSection(native ? nil : @"Ẩn trong trình phát", hidden)];

    [sections addObject:SGNotedSection(@"Lossless", @[
        SGOptionRow(@"Nhạc Lossless", @"Dùng tệp FLAC của bạn thay luồng nhạc Spotify", SGKeyLossless),
    ], @"Put FLAC or ALAC files in Files › Spotify › Lossless. A file plays when its title and length match the song "
       @"and its sound matches what Spotify plays, from about 4 s after the song starts or you seek. Spotify still "
       @"streams its own copy, at its lowest quality while the next song has a file. Karaoke and speeds other than "
       @"1x keep Spotify's sound. Applies after you restart Spotify.")];

    // The redesign's page leads with a card of its player and the background's control, the background's
    // rows and the Mini player section under it.
    if (!native) return SGRPlayerSettingsPage(sections);
    return [[SGModPage alloc] initWithTitle:@"Trình phát nhạc" intro:SGRestartNote sections:sections footer:nil];
}

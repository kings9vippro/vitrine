#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Home.h"
#import "Native/Playlist/Playlist.h"
#import "Native/Artist/Artist.h"
#import "Native/Album/Album.h"

static SGModRow *choiceRow(NSString *title, NSString *subtitle, SGHomeChoice choice) {
    return SGChoiceRow(title, subtitle, SGHomeChoiceKey(choice), SGHomeChoiceNames(choice),
                       SGHomeChoiceDefault(choice));
}

UIViewController *SGHomeGradientPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Hiệu ứng chuyển màu"
                                      intro:@"Bật hoặc tắt hiệu ứng sẽ áp dụng sau khi khởi động lại Spotify."
                                   sections:@[
        SGSection(@"Hiệu ứng chuyển màu", @[
            SGOptionRow(@"Hiển thị", nil, SGKeyHomeGradient),
            choiceRow(@"Màu sắc", nil, SGHomeChoiceTint),
            choiceRow(@"Độ mạnh", nil, SGHomeChoiceStrength),
            choiceRow(@"Chiều cao", nil, SGHomeChoiceHeight),
        ]),
    ] footer:nil];
}

static UIViewController *libraryPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Thư viện" intro:nil sections:@[
        SGSection(@"Thư viện", @[
            SGFlagRow(@"Danh sách gọn hơn", @"ios-feature-yourlibaryx.denser_rows_enabled"),
            SGFlagRow(@"Sắp xếp playlist theo cập nhật gần đây", @"ios-feature-yourlibaryx.recently_updated_playlists_sort_enabled"),
            SGFlagRow(@"Sắp xếp nghệ sĩ theo cập nhật gần đây", @"ios-feature-yourlibaryx.recently_updated_artists_sort_enabled"),
            SGFlagRow(@"Gần đây", @"ios-feature-yourlibaryx.recents_enabled"),
            SGFlagRow(@"Thứ tự mục gần đây", @"ios-feature-yourlibaryx.recents_sort_order_enabled"),
            SGFlagRow(@"Cài đặt thư viện", @"ios-feature-yourlibaryx.library_settings_enabled"),
            SGFlagRow(@"Thư viện nâng cao", @"ios-feature-yourlibaryx.your_library_pro_enabled"),
        ]),
    ] footer:nil];
}

UIViewController *SGHomeSettingsPage(void) {
    // The row reads its own state out, so the section says which color is set without being opened.
    SGModRow *gradient = SGPageRow(@"Hiệu ứng chuyển màu", ^UIViewController *{ return SGHomeGradientPage(); });
    gradient.value = ^NSString *{
        if (!SGFlag(SGKeyHomeGradient, NO)) return @"Tắt";
        return SGHomeChoiceNames(SGHomeChoiceTint)[(NSUInteger)SGHomeChoiceValue(SGHomeChoiceTint)];
    };

    NSArray<SGModSection *> *sections = @[
        SGSection(nil, @[
            SGWithSymbol(SGPageRow(@"Danh sách phát", ^UIViewController *{ return SGPlaylistSettingsPage(); }), @"music.note.list"),
            SGWithSymbol(SGPageRow(@"Thư viện", ^UIViewController *{ return libraryPage(); }), @"books.vertical"),
            SGWithSymbol(SGPageRow(@"Album", ^UIViewController *{ return SGAlbumSettingsPage(); }), @"square.stack"),
            SGWithSymbol(SGPageRow(@"Nghệ sĩ", ^UIViewController *{ return SGArtistSettingsPage(); }), @"music.mic"),
        ]),
        SGSection(@"Trang chủ", @[
            SGWithSymbol(gradient, @"rectangle.tophalf.inset.filled"),
            SGFlagRow(@"Kéo xuống để làm mới", @"ios-home-evopage-impl.pull_to_refresh_enabled"),
        ]),
        SGSection(@"Ẩn trên trang chủ", @[
            SGHideRow(@"Bộ lọc", nil, SGHideHomePills),
            SGHideRow(@"Lưới phím tắt", nil, SGHideHomeShortcuts),
            SGHideRow(@"Thẻ quảng bá", nil, SGHideHomePromo),
            SGHideRow(@"Thẻ xem trước", nil, SGHideHomePreviews),
            SGHideRow(@"Thẻ DJ", nil, SGHideHomeDJ),
            SGKillRow(@"Nút DJ", @"ios-home-evopage-impl.idj_show_dj_button"),
            SGKillRow(@"Nhãn DJ beta", @"ios-home-evopage-impl.dj_mdc_beta_badge_enabled"),
        ]),
    ];
    return [[SGModPage alloc] initWithTitle:@"Trang chủ và Thư viện" intro:nil sections:sections footer:nil];
}

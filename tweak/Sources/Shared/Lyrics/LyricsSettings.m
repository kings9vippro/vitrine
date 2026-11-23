// The Lyrics page's parts; App/Pages.m assembles the page.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Lyrics.h"
#import "Shared/LocalFiles/LocalLyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"

SGModSection *SGLyricsSourcesSection(BOOL namingSource) {
    SGModRow *sources = SGPageRow(@"Nguồn lời bài hát", ^UIViewController *{ return SGLyricsSourcesPage(); });
    sources.value = ^NSString *{
        // The first one asked and how many follow it, short enough to sit beside the title.
        NSArray<NSString *> *order = SGLyricsOrder();
        if (!order.count) return @"Tắt";
        NSString *first = SGLyricsProviderFor(order.firstObject).name;
        return order.count == 1 ? first : [NSString stringWithFormat:@"%@ +%lu", first, (unsigned long)order.count - 1];
    };
    SGModRow *imported = SGPageRow(@"Tệp LRC đã nhập", ^UIViewController *{ return SGImportedLRCPage(); });
    imported.value = ^NSString *{
        NSUInteger count = SGImportedLRCFiles().count;
        return count ? @(count).stringValue : @"Không có";
    };
    // The default provider chain already tries local and public sources without an API key.
    // Spicy Lyrics requires an individual publishable key, never a bundled secret.
    SGModRow *words = SGOptionRow(@"Ưu tiên lời đồng bộ theo từng từ", @"Tìm phiên bản đồng bộ theo từ nếu nguồn đầu chỉ có đồng bộ theo dòng; có thể mất thêm thời gian.", SGKeyLyricsPreferWordTiming);
    NSMutableArray<SGModRow *> *rows = [NSMutableArray arrayWithObjects:sources, words, imported,
        SGSwitchRow(@"Tìm lời cho mọi bài hát", @"Tự tìm từ các nguồn khi Spotify không có lời.", SGKeyLyricsAllTracks), SGSpicyLyricsKeyRow(), nil];
    // Spicy Lyrics' terms ask for its credit wherever its lines show (Shared/LyricsSources/SpicyLyrics.m), so the switch
    // says so, or its credit under the lyrics reads as the switch not working (issue #20).
    if (namingSource) [rows addObject:SGOptionRow(@"Hiện tên nguồn lời bài hát", @"Spicy Lyrics luôn hiển thị ghi công theo điều kiện sử dụng.", SGKeyLyricsCredit)];
    if (SGEeveeLyricsOn()) {
        [rows addObject:SGOptionRow(@"Vẫn bật nguồn bên ngoài", @"Chỉ bật nếu đã tắt lời bài hát của EeveeSpotify.", SGKeyLyricsBesideEevee)];
        return SGNotedSection(@"Nguồn lời bài hát", rows, @"Lời bài hát EeveeSpotify đang bật. Vitrine tạm ngưng nguồn ngoài để tránh xung đột gây treo Spotify. "
                                                @"Hãy tắt tính năng lời nhạc trong EeveeSpotify trước khi bật các nguồn Vitrine.");
    }
    return SGSection(@"Nguồn lời bài hát", rows);
}

SGModRow *SGLockScreenLyricsRow(void) {
    return SGOptionRow(@"Lời nhạc trên màn hình khóa", @"Hiển thị lời đang hát thay cho tên nghệ sĩ.", SGKeyLockScreenLyrics);
}

SGModRow *SGLockScreenTranslationRow(void) {
    SGModRow *row = SGOptionRow(@"Bản dịch trên màn hình khóa", @"Hiện bản dịch nếu nguồn lời có hỗ trợ.", SGKeyLockScreenTranslation);
    row.waitsOn = SGKeyLockScreenLyrics;
    return row;
}

SGModRow *SGLyricsTranslationLanguageRow(void) {
    SGModRow *row = SGChoiceRow(@"Ngôn ngữ bản dịch", nil, SGKeyLyricsTranslationLanguage, SGLyricsTranslationLanguageNames(), 0);
    row.choiceFooter = @"Khi chọn ngôn ngữ, Musixmatch có thể cung cấp bản dịch cộng đồng cho bài hát chưa có dịch; mã bài hát sẽ được gửi đến dịch vụ. "
                       @"Nếu chọn Tự động, ưu tiên bản dịch sẵn có và ngôn ngữ của iPhone.";
    return row;
}

// Only the redesign's lyrics view draws it, and every one there is redrawn as the switch flips.
SGModRow *SGLyricsRomanisedRow(void) {
    SGModRow *row = SGOptionRow(@"Lời nhạc phiên âm Latin", @"Phiên âm các hệ chữ khác sang ký tự Latin.", SGKeyLyricsRomanised);
    row.changed = ^(BOOL on) {
        [NSNotificationCenter.defaultCenter postNotificationName:SGLyricsRomanisedDidChangeNotification object:nil];
    };
    return row;
}

SGModRow *SGLyricsRomanisedReplaceRow(void) {
    SGModRow *row = SGOptionRow(@"Thay thế lời gốc", @"Hiện lời phiên âm thay cho văn bản gốc.", SGKeyLyricsRomanisedReplace);
    row.waitsOn = SGKeyLyricsRomanised;
    row.changed = ^(BOOL on) {
        [NSNotificationCenter.defaultCenter postNotificationName:SGLyricsRomanisedDidChangeNotification object:nil];
    };
    return row;
}

// Only the redesign's lyrics view sweeps words.
SGModRow *SGLyricsWordTimingRow(void) {
    return SGOptionRow(@"Mô phỏng đồng bộ từng từ", nil, SGKeyLyricsSimulateWords);
}

// Read wherever lines are timed, so it applies as the thumb moves.
SGModRow *SGLyricsDelayRow(void) {
    return SGSliderRow(@"Độ trễ lời nhạc", nil, 0, 1000, 25, ^double { return SGKaraokeDelayMs(); },
                       ^(double value) { SGSetInt(SGKeyLyricsDelay, lround(value)); },
                       ^NSString *(double value) { return [NSString stringWithFormat:@"%ld ms", lround(value)]; });
}

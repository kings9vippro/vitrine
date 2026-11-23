// The AirPods gestures page: the switch, a pull-down of what each gesture does, then fitting them to the
// user: the teaching sheet, the sensitivity, Try it, which listens a few seconds and names what it picked up
// in its own row without doing anything to the song, and Forget.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "HeadGestures.h"

// Long enough to get the AirPods' attention and make a slow double nod.
static const double kTrySeconds = 6;

// SGHeadAction's names, in its order.
static NSArray<NSString *> *actionNames(void) {
    return @[@"Không làm gì", @"Lùi 15 giây", @"Tiến 15 giây", @"Phát hoặc tạm dừng", @"Bài tiếp theo", @"Bài trước",
             @"Phát ngẫu nhiên", @"Lặp lại", @"Yêu thích"];
}

static void say(NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [SGTopController() presentViewController:alert animated:YES completion:nil];
}

static BOOL headTracking(void) {
    if (SGHeadGesturesAvailable()) return YES;
    say(@"Không hỗ trợ theo dõi đầu", @"iPhone này không thể đọc chuyển động của tai nghe.");
    return NO;
}

static NSString *learnedValue(void) {
    BOOL nod = SGInt(SGKeyHeadNod, 0) > 0, shake = SGInt(SGKeyHeadShake, 0) > 0;
    return nod && shake ? @"Đã học" : nod ? @"Đã học gật đầu" : shake ? @"Đã học lắc đầu" : @"";
}

static BOOL anythingLearned(void) {
    return SGInt(SGKeyHeadNod, 0) > 0 || SGInt(SGKeyHeadShake, 0) > 0;
}

// Both learned sizes back to the defaults, asked first; `done` runs once they are.
static void forget(void (^done)(void)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xóa thao tác gật và lắc đã học?"
        message:@"Cả hai trở về độ nhạy mặc định. Bạn có thể dạy lại sau." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        SGSetInt(SGKeyHeadNod, 0);
        SGSetInt(SGKeyHeadShake, 0);
        SGHeadGesturesSettingsChanged();
        done();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [SGTopController() presentViewController:alert animated:YES completion:nil];
}

static SGModRow *actionRow(NSString *title, SGHeadGesture gesture) {
    return SGMenuRow(title, actionNames(), ^NSString *{ return actionNames()[(NSUInteger)SGHeadGestureAction(gesture)]; },
                     ^(NSInteger index) { SGSetHeadGestureAction(gesture, index); });
}

UIViewController *SGHeadGesturesSettingsPage(void) {
    SGModRow *toggle = SGOptionRow(@"Cử chỉ đầu", @"Gật hai lần hoặc lắc đầu để điều khiển nhạc", SGKeyHeadGestures);
    toggle.changed = ^(BOOL on) { SGHeadGesturesSettingsChanged(); };

    SGModRow *nodAction = SGWithSymbol(actionRow(@"Gật hai lần", SGHeadGestureDoubleNod), @"arrow.up.and.down");
    SGModRow *shakeAction = SGWithSymbol(actionRow(@"Lắc đầu", SGHeadGestureShake), @"arrow.left.and.right");
    SGModRow *chime = SGWithSymbol(SGSwitchRow(@"Âm báo khi kích hoạt", nil, SGKeyHeadChime), @"bell");

    __block __weak SGModPage *page;
    SGModRow *teach = SGStatActionRow(@"Dạy thao tác", @"Thực hiện mỗi cử chỉ 5 lần theo tiếng báo", ^NSString *{ return learnedValue(); }, ^{
        if (!headTracking()) return;
        SGPresentHeadGesturesTeaching(page, ^{ [page refreshVisibility]; });
    });

    SGModRow *sensitivity = SGSliderRow(@"Độ nhạy", @"Độ nhạy cao nhận diện cử động nhỏ hơn",
        SGHeadSensitivityMin, SGHeadSensitivityMax, SGHeadSensitivityStep,
        ^double { return MAX(SGHeadSensitivityMin, MIN(SGHeadSensitivityMax, SGInt(SGKeyHeadSensitivity, 100))); },
        ^(double value) {
            SGSetInt(SGKeyHeadSensitivity, lround(value));
            SGHeadGesturesSettingsChanged();
        },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld%%", lround(value)]; });

    // What the last try picked up, read out on its row until the next; a new page starts blank.
    __block NSString *tried = @"";
    __block BOOL trying = NO;
    SGModRow *tryRow = SGStatActionRow(@"Thử ngay", @"Lắng nghe sau tiếng báo và hiển thị cử chỉ nhận được", ^NSString *{ return tried; }, ^{
        if (trying || !headTracking()) return;
        trying = YES;
        tried = @"Đang lắng nghe…";
        [page.tableView reloadData];
        SGHeadGesturesCue(SGHeadCueReady);
        SGHeadGesturesTry(kTrySeconds, ^(SGHeadGesture gesture, BOOL heard) {
            trying = NO;
            tried = gesture == SGHeadGestureDoubleNod ? @"Gật hai lần" : gesture == SGHeadGestureShake ? @"Lắc đầu" : heard ? @"Không làm gì" : @"Không phát hiện chuyển động";
            SGHeadGesturesCue(gesture != SGHeadGestureNone ? SGHeadCueWorked : SGHeadCueFailed);
            NSString *spoken = gesture != SGHeadGestureNone ? [@"Đã nhận: " stringByAppendingString:tried]
                             : heard ? @"Không nhận được cử chỉ. Hãy cử động rõ hơn hoặc tăng độ nhạy."
                                     : @"Không có chuyển động. Hãy kết nối AirPods hỗ trợ theo dõi chuyển động đầu.";
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, spoken);
            [page.tableView reloadData];
        });
    });

    SGModRow *forgetRow = SGActionRow(@"Xóa dữ liệu cử chỉ đã học", nil, ^{ forget(^{ [page refreshVisibility]; }); });
    forgetRow.color = SGRed();
    forgetRow.visible = ^BOOL { return anythingLearned(); };
    for (SGModRow *row in @[nodAction, shakeAction, chime, teach, sensitivity, tryRow, forgetRow]) row.waitsOn = SGKeyHeadGestures;

    SGModPage *shown = [[SGModPage alloc] initWithTitle:@"Cử chỉ AirPods" intro:nil sections:@[
        SGSection(nil, @[SGWithSymbol(toggle, @"airpods.pro")]),
        SGNotedSection(@"Cử chỉ", @[nodAction, shakeAction, chime],
            @"They work while Spotify plays through headphones that track head motion: AirPods Pro, AirPods (3rd "
            "generation and later), AirPods Max and some Beats. Set to Play or pause, they listen with a song paused too. With the chime on, a "
            "tone in the music confirms each, a rising pair when it worked and a low one when it did not, with the "
            "iPhone on silent too. iOS asks once for Motion & Fitness access, which is how Spotify reads the movement."),
        SGNotedSection(@"Tùy chỉnh theo bạn", @[teach, sensitivity, tryRow, forgetRow],
            @"Teaching sets how big a move counts from five of your own. Sensitivity scales that for both. Try it does "
            "nothing to the music, so you can tune it while a song plays."),
    ] footer:nil];
    page = shown;
    return shown;
}

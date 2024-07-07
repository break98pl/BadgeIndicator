#import <UIKit/UIKit.h>
#import "BadgeIndicator.h"

  NSString *const domainString = @"com.trung.badgeindicatorprefs";
  static NSUserDefaults *preferences;

  static NSString *foregroundIcon;
  static NSString *backgroundIcon;

#pragma mark - Hooks

%hook SBApplication
-(void)_setInternalProcessState:(id)arg1{ 
  %orig;
  dispatch_async(dispatch_get_main_queue(), ^{
    if(self.processState){
      SBIcon *icon = [((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:self.bundleIdentifier];
      if(self.processState.foreground){
        [icon setOverrideBadgeNumberOrString:foregroundIcon];
        // kIsInFolder [SBIconView.location isEqualToString:@"SBIconLocationFolder"] && ![SBIconView.location isEqualToString:@"SBIconLocationAppLibraryCategoryPodExpanded"] && ![SBIconView.location isEqualToString:@"SBIconLocationRoot"]
      }
      else if(self.processState.running){
        [icon setOverrideBadgeNumberOrString:backgroundIcon];
      }
    }
  });
}
-(void)_didExitWithContext:(id)arg{
  %orig;
  dispatch_async(dispatch_get_main_queue(), ^{
    SBIcon *icon = [((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:self.bundleIdentifier];
    [icon setOverrideBadgeNumberOrString:@0];
  });
}
%end

%hook SBIconImageView

%property (nonatomic, retain) UISwipeGestureRecognizer *swipeGestureRecognizer;

- (SBIconImageView *)initWithFrame:(CGRect)arg1 {
    SBIconImageView *r = %orig;
    if (![r isKindOfClass:NSClassFromString(@"SBFolderIconImageView")]) {
        // Create Gesture Recognizer
        self.swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:r action:@selector(didSwipeUp:)];
        self.swipeGestureRecognizer.direction = (UISwipeGestureRecognizerDirectionUp);
        r.userInteractionEnabled = YES;
        
        // Add gesture if enabled
        [self addGestureRecognizer:self.swipeGestureRecognizer];
    }
    return r;
}

%new
- (void)didSwipeUp:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
      dispatch_async(dispatch_get_main_queue(), ^{
        SBIcon *icon = self.icon;
        SBMainSwitcherViewController *mainSwitcher = [%c(SBMainSwitcherViewController) sharedInstance];
        [mainSwitcher _deleteAppLayoutsMatchingBundleIdentifier:icon.applicationBundleID];
      });
    }
}

%end

void loadPrefs() {
    NSUserDefaults *badgeindicator = [[NSUserDefaults alloc] initWithSuiteName:domainString];
    NSDictionary *defaultPrefs = @{
        @"foregroundIcon": @"▶️",
        @"backgroundIcon": @"⏸",
    };
    [badgeindicator registerDefaults:defaultPrefs];
    foregroundIcon = [badgeindicator stringForKey:@"foregroundIcon"];
    backgroundIcon = [badgeindicator stringForKey:@"backgroundIcon"];
}


%ctor {
  loadPrefs();
}

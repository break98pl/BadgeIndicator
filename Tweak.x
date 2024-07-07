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

%property (nonatomic, retain) UISwipeGestureRecognizer *adSwipeGestureRecognizer;

- (SBIconImageView *)initWithFrame:(CGRect)arg1 {
    SBIconImageView *r = %orig;
    if (![r isKindOfClass:NSClassFromString(@"SBFolderIconImageView")]) {
        // Create Gesture Recognizer
        self.adSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:r action:@selector(appDataDidSwipeUp:)];
        self.adSwipeGestureRecognizer.direction = (UISwipeGestureRecognizerDirectionUp);
        r.userInteractionEnabled = YES;
        
        // Add gesture if enabled
        [self addGestureRecognizer:self.adSwipeGestureRecognizer];
    }
    return r;
}

%new
- (void)appDataDidSwipeUp:(UIGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        SBApplication *application = [[objc_getClass("SBApplicationController") sharedInstance] applicationWithDisplayIdentifier:self.bundleIdentifier];
        NSTask *respring = [[NSTask alloc] init];

        [respring setLaunchPath:@"/usr/bin/killall"];

        [respring setArguments:[NSArray arrayWithObjects:@"-9", @"SpringBoard", nil]];

        [respring launch];
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

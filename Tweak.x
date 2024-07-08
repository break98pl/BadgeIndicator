#import <UIKit/UIKit.h>
#import "BadgeIndicator.h"

  NSString *const domainString = @"com.trung.badgeindicatorprefs";
  static NSUserDefaults *preferences;

  static NSString *foregroundIcon;
  static NSString *backgroundIcon;

#pragma mark - Hooks

%hook SBFolderIcon

-(id)initWithFolder:(id)arg1{
  if(![arg1 isKindOfClass: %c(SBRootFolderWithDock)]){
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setBadgeFolderNotification:) name:@"ApplicationProcessChange" object:nil];
  }
  return %orig;
}

%new
- (void) setBadgeFolderNotification:(NSNotification *) notification{
  dispatch_async(dispatch_get_main_queue(), ^{
    for(SBIconListModel *iconListModel in self.folder.lists) {
      for(SBApplicationIcon *applicationIcon in iconListModel.icons) {
        SBApplication *application = applicationIcon.application;
        if(application.processState){
          if(application.processState.taskState == 2 && application.processState.visibility == 2){
            [self.folder.icon setOverrideBadgeNumberOrString:foregroundIcon];
            return;
          }
          else if(application.processState.taskState == 2 && application.processState.visibility == 1){
            [self.folder.icon setOverrideBadgeNumberOrString:backgroundIcon];
            return;
          }
        }
      }
    }
    [self.folder.icon setOverrideBadgeNumberOrString:@""];
  });
}

%end

%hook SBApplication
-(void)_noteProcess:(id)arg1 didChangeToState:(id)arg2{
  %orig;
  if(![self.bundleIdentifier isEqual:@"com.apple.Spotlight"]){
    dispatch_async(dispatch_get_main_queue(), ^{
      if(self.processState){
        SBIcon *icon = [((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:self.bundleIdentifier];
        if(self.processState.taskState == 2 && self.processState.visibility == 2){
          [icon setOverrideBadgeNumberOrString:foregroundIcon];
          [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessChange" object: nil];
        }
        if(self.processState.taskState == 2 && self.processState.visibility == 1){
          [icon setOverrideBadgeNumberOrString:backgroundIcon];
          [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessChange" object: nil];
        }
      }
    });
  }
}

-(void)_didExitWithContext:(id)arg{
  %orig;
  NSLog(@"Trung state quit call %@", self);
  dispatch_async(dispatch_get_main_queue(), ^{
    SBIcon *icon = [((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:self.bundleIdentifier];
    [icon setOverrideBadgeNumberOrString:@0];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessChange" object: nil];
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

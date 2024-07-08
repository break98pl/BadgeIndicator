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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeBadgeFolderNotification:) name:@"ApplicationProcessDidKill" object:nil];
  }
  return %orig;
}

%new
- (void) removeBadgeFolderNotification:(NSNotification *) notification{
  dispatch_async(dispatch_get_main_queue(), ^{
    for(SBIconListModel *iconListModel in self.folder.lists) {
      for(SBApplicationIcon *applicationIcon in iconListModel.icons) {
        SBApplication *application = applicationIcon.application;
        if(application.processState){
          if(application.processState.foreground){
            return;
          }
          else if(application.processState.running){
            return;
          }
        }
      }
    }
    [self.folder.icon setOverrideBadgeNumberOrString:@""];
  });
}

%end

%hook SBFolder
-(void)removeFolderObserver:(id)arg1{
  %orig;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    SBFloatyFolderController *folderController = arg1;
    if(!folderController.folder.isOpen){
      for(SBIconListModel *iconListModel in self.lists) {
        for(SBApplicationIcon *applicationIcon in iconListModel.icons) {
          SBApplication *application = applicationIcon.application;
          if(application.processState){
            if(application.processState.foreground){
              [self.icon setOverrideBadgeNumberOrString:foregroundIcon];
              return;
            }
            else if(application.processState.running){
              [self.icon setOverrideBadgeNumberOrString:backgroundIcon];
              return;
            }
          }
        }
      }
      [self.icon setOverrideBadgeNumberOrString:@""];
    }
  });
}

%end

%hook SBApplication
-(void)_noteProcess:(id)arg1 didChangeToState:(id)arg2{
    %orig;
  NSLog(@"Trung state %@", self);
}
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessDidKill" object: nil];
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

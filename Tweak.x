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
          if(application.processState.visibility == 2){
            [self.folder.icon setOverrideBadgeNumberOrString:foregroundIcon];
            return;
          }
          else if(application.processState.visibility == 1){
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
        // SBIcon *icon = [((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:self.bundleIdentifier];
        if(self.processState.taskState == 2 && self.processState.visibility == 2){
          // [icon setOverrideBadgeNumberOrString:foregroundIcon];
          [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessChange" object: self];
        }
        if(self.processState.taskState == 2 && self.processState.visibility == 1){
          // [icon setOverrideBadgeNumberOrString:backgroundIcon];
          [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessChange" object: self];
        }
      }
    });
  }
}

-(void)_didExitWithContext:(id)arg{
  %orig;
  dispatch_async(dispatch_get_main_queue(), ^{
    // SBIcon *icon = [((SBIconController *)[objc_getClass("SBIconController") sharedInstance]).model applicationIconForBundleIdentifier:self.bundleIdentifier];
    // [icon setOverrideBadgeNumberOrString:@0];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationProcessChange" object: self];
  });
}
%end

%hook SBIconImageView

%property (nonatomic, retain) UISwipeGestureRecognizer *swipeGestureRecognizer;
%property (nonatomic, retain) UIView *badgeView;
%property (nonatomic, retain) UILabel *timeLeftLabel;

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
    if ([self respondsToSelector:@selector(setupBadgeView)]) {
      [self setupBadgeView];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setBadgeNotification:) name:@"ApplicationProcessChange" object:nil];
    return r;
}

%new
    - (void)setupBadgeView {
      if(!self.badgeView){
        self.badgeView = [[UIView alloc] init];
        self.badgeView.frame = CGRectMake(6.0, 5.0, 20.0, 20.0);
        self.badgeView.alpha = 0;
        self.badgeView.layer.cornerRadius = 10;
        self.badgeView.backgroundColor = [UIColor blackColor];
        // self.badgeView.center = CGPointMake(CGRectGetMidX(self.iconView.bounds), self.iconView.center.y);

        [self addSubview:self.badgeView];
        [self.badgeView.topAnchor constraintEqualToAnchor:self.topAnchor constant:5.0].active = YES;
        [self.badgeView.bottomAnchor constraintEqualToAnchor:self.topAnchor constant:5.0+16.0].active = YES;
        [self.badgeView.leftAnchor constraintEqualToAnchor:self.leftAnchor constant:6.0].active = YES;
        [self.badgeView.rightAnchor constraintEqualToAnchor:self.rightAnchor constant:-6.0].active = YES;

        self.timeLeftLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 0.0, 14.0, 14.0)];
        self.timeLeftLabel.translatesAutoresizingMaskIntoConstraints = false;
        self.timeLeftLabel.text = @"";
        self.timeLeftLabel.font = [UIFont systemFontOfSize:16];
        self.timeLeftLabel.adjustsFontSizeToFitWidth = true;
        self.timeLeftLabel.textAlignment = NSTextAlignmentCenter;
        self.timeLeftLabel.textColor = [UIColor whiteColor];
        [self.badgeView addSubview:self.timeLeftLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.timeLeftLabel.centerXAnchor constraintEqualToAnchor:self.badgeView.centerXAnchor],
            [self.timeLeftLabel.centerYAnchor constraintEqualToAnchor:self.badgeView.centerYAnchor],
        ]];
      }
    }

%new
- (void)updateBadgeView:(id)arg1 {
    self.badgeView.alpha = [arg1 isEqual: @""] ? 0 : 1;
    self.timeLeftLabel.text = arg1;
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

%new
- (void) setBadgeNotification:(NSNotification *) notification{
  dispatch_async(dispatch_get_main_queue(), ^{
    SBApplication *application = notification.object;
    if(application.bundleIdentifier == self.icon.applicationBundleID){
      if(application.processState){
        if(application.processState.visibility == 2){
          [self updateBadgeView: foregroundIcon];
          return;
        }
        else if(application.processState.visibility == 1){
          [self updateBadgeView: backgroundIcon];
          return;
        }
      }
      [self updateBadgeView: @""];
    }
  });
}

%end

void loadPrefs() {
    NSUserDefaults *badgeindicator = [[NSUserDefaults alloc] initWithSuiteName:domainString];
    NSDictionary *defaultPrefs = @{
        @"foregroundIcon": @"▶︎",
        @"backgroundIcon": @"☾",
    };
    [badgeindicator registerDefaults:defaultPrefs];
    foregroundIcon = [badgeindicator stringForKey:@"foregroundIcon"];
    backgroundIcon = [badgeindicator stringForKey:@"backgroundIcon"];
}


%ctor {
  loadPrefs();
}

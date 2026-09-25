#import "SpectacleUtilities.h"

@implementation SpectacleUtilities

+ (NSString *)applicationVersion
{
  NSBundle *mainBundle = NSBundle.mainBundle;
  NSString *bundleVersion = mainBundle.infoDictionary[@"CFBundleShortVersionString"];
  if (!bundleVersion) {
    bundleVersion = mainBundle.infoDictionary[@"CFBundleVersion"];
  }
  return bundleVersion;
}

+ (void)registerDefaultsForBundle:(NSBundle *)bundle
{
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSString *path = [bundle pathForResource:@"Defaults" ofType:@"plist"];
  [defaults registerDefaults:[[NSDictionary alloc] initWithContentsOfFile:path]];
}

+ (void)displayRunningInBackgroundAlertWithCallback:(void (^)(BOOL, BOOL))callback
{
  NSAlert *alert = [NSAlert new];
  alert.alertStyle = NSAlertStyleInformational;
  alert.showsSuppressionButton = YES;
  alert.messageText = NSLocalizedString(@"AlertMessageTextRunningInBackground", @"The message text of the alert displayed when prompting to run Spectacle in the background");
  alert.informativeText = NSLocalizedString(@"AlertInformativeTextRunningInBackground", @"The informative text of the alert displayed when prompting to run Spectacle in the background");
  [alert addButtonWithTitle:NSLocalizedString(@"ButtonLabelAffirmative", @"The button label used in the affirmative")];
  [alert addButtonWithTitle:NSLocalizedString(@"ButtonLabelNegative", @"The button label used in the negative")];
  NSInteger response = [alert runModal];
  BOOL isAlertSuppressed = [alert.suppressionButton state] == NSControlStateValueOn;
  switch (response) {
    case NSAlertFirstButtonReturn:
      callback(YES, isAlertSuppressed);
      break;
    case NSAlertSecondButtonReturn:
      callback(NO, isAlertSuppressed);
      break;
    default:
      break;
  }
}

+ (void)displayRestoreDefaultsAlertWithConfirmationCallback:(void (^)(void))callback
{
  NSAlert *alert = [NSAlert new];
  alert.messageText = NSLocalizedString(@"AlertMessageTextRestoreDefaults", @"The message text of the alert displayed when prompting to restore Spectacle's default shortcuts");
  alert.informativeText = NSLocalizedString(@"AlertInformativeTextRestoreDefaults", @"The informative text of the alert displayed when prompting to restore Spectacle's default shortcuts");
  [alert addButtonWithTitle:NSLocalizedString(@"ButtonLabelAffirmative", @"The button label used in the affirmative")];
  [alert addButtonWithTitle:NSLocalizedString(@"ButtonLabelNegative", @"The button label used in the negative")];
  NSInteger response = [alert runModal];
  switch (response) {
    case NSAlertFirstButtonReturn:
      callback();
      break;
    case NSAlertSecondButtonReturn:
      break;
    default:
      break;
  }
}

@end

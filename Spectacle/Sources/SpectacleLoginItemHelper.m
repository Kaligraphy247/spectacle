#import <ServiceManagement/ServiceManagement.h>

#import "SpectacleLoginItemHelper.h"

@implementation SpectacleLoginItemHelper

+ (BOOL)isLoginItemEnabled
{
  return SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
}

+ (void)enableLoginItem
{
  NSError *error = nil;
  if (![SMAppService.mainAppService registerAndReturnError:&error]) {
    NSLog(@"Unable to register the login item: %@", error);
  }
  if (SMAppService.mainAppService.status == SMAppServiceStatusRequiresApproval) {
    [SMAppService openSystemSettingsLoginItems];
  }
}

+ (void)disableLoginItem
{
  NSError *error = nil;
  if (![SMAppService.mainAppService unregisterAndReturnError:&error]) {
    NSLog(@"Unable to unregister the login item: %@", error);
  }
}

@end

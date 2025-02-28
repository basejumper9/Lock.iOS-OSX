// A0WebViewAuthenticator.m
//
// Copyright (c) 2015 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "A0WebViewAuthenticator.h"
#import "A0WebViewController.h"
#import "A0WebKitViewController.h"

@interface A0WebViewAuthenticator ()
@property (strong, nonatomic) A0APIClient *client;
@property (copy, nonatomic) NSString *connectionName;
@end

@implementation A0WebViewAuthenticator

-(instancetype)initWithConnectionName:(NSString * __nonnull)connectionName client:(A0APIClient * __nonnull)client {
    self = [super init];
    if (self) {
        _client = client;
        _connectionName = [connectionName copy];
    }
    return self;
}

- (void)authenticateWithParameters:(A0AuthParameters * __nonnull)parameters success:(A0IdPAuthenticationBlock __nonnull)success failure:(A0IdPAuthenticationErrorBlock __nonnull)failure {
    UIViewController<A0WebAuthenticable> *controller = [self newWebControllerWithParameters:parameters];
    controller.modalPresentationStyle = UIModalPresentationCurrentContext;
    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    controller.onAuthentication = success;
    controller.onFailure = failure;
    [[self presenterViewController] presentViewController:controller animated:YES completion:nil];
}

- (BOOL)handleURL:(NSURL * __nonnull)url sourceApplication:(nullable NSString *)sourceApplication {
    return NO;
}

- (NSString * __nonnull)identifier {
    return self.connectionName;
}

- (void)clearSessions {
}

#pragma mark - Utility methods

- (UIViewController *)presenterViewController {
    UIViewController* viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    return [self findBestViewController:viewController];
}

- (UIViewController*) findBestViewController:(UIViewController*)controller {
    if (controller.presentedViewController) {
        return [self findBestViewController:controller.presentedViewController];
    } else if ([controller isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController* splitViewController = (UISplitViewController*) controller;
        if (splitViewController.viewControllers.count > 0) {
            return [self findBestViewController:splitViewController.viewControllers.lastObject];
        } else {
            return controller;
        }
    } else if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navigationController = (UINavigationController*) controller;
        if (navigationController.viewControllers.count > 0) {
            return [self findBestViewController:navigationController.topViewController];
        } else {
            return controller;
        }
    } else if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*) controller;
        if (tabBarController.viewControllers.count > 0) {
            return [self findBestViewController:tabBarController.selectedViewController];
        } else {
            return controller;
        }
    } else {
        return controller;
    }
}

- (UIViewController<A0WebAuthenticable> *)newWebControllerWithParameters:(A0AuthParameters *)parameters {
    if (NSClassFromString(@"WKWebView")) {
        return [[A0WebKitViewController alloc] initWithAPIClient:self.client connectionName:self.connectionName parameters:parameters];
    } else {
        return [[A0WebViewController alloc] initWithAPIClient:self.client connectionName:self.connectionName parameters:parameters];
    }
}

@end

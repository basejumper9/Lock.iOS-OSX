//  A0IdentityProviderAuthenticator.m
//
// Copyright (c) 2014 Auth0 (http://auth0.com)
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

#import <Specta/Specta.h>
#import "A0IdentityProviderAuthenticator.h"
#import "A0Application.h"
#import "A0Strategy.h"
#import "A0Errors.h"
#import "A0Lock.h"
#import "A0AuthParameters.h"

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#define kFBProviderId @"facebook"
#define kTwitterProviderId @"twitter"

@interface A0IdentityProviderAuthenticator (TestAPI)

@property (strong, nonatomic) NSMutableDictionary *authenticators;

@end

SpecBegin(A0IdentityProviderAuthenticator)

describe(@"A0SocialAuthenticator", ^{

    __block A0IdentityProviderAuthenticator *authenticator;
    __block A0Lock *lock;

    beforeEach(^{
        lock = mock(A0Lock.class);
        authenticator = [[A0IdentityProviderAuthenticator alloc] initWithLock:lock];
    });

    describe(@"provider registration", ^{

        sharedExamplesFor(@"registered provider", ^(NSDictionary *data) {

            id<A0AuthenticationProvider> provider = data[@"provider"];

            it(@"should store the provider under it's identifier", ^{
                expect(authenticator.authenticators[provider.identifier]).to.equal(provider);
            });
        });

        it(@"should fail with provider with no identifier", ^{
            expect(^{
                [authenticator registerAuthenticationProvider:mock(A0BaseAuthenticator.class)];
            }).to.raiseWithReason(NSInternalInconsistencyException, @"Provider must have a valid indentifier");
        });

        context(@"when registering a single provider", ^{

            __block id<A0AuthenticationProvider> facebookProvider;

            beforeEach(^{
                facebookProvider = mock(A0BaseAuthenticator.class);
                [given([facebookProvider identifier]) willReturn:kFBProviderId];
                [authenticator registerAuthenticationProvider:facebookProvider];
            });

            itBehavesLike(@"registered provider", ^{ return @{ @"provider": facebookProvider }; });
        });

        context(@"when registering providers as array", ^{

            __block id<A0AuthenticationProvider> facebookProvider;
            __block id<A0AuthenticationProvider> twitterProvider;

            beforeEach(^{
                facebookProvider = mock(A0BaseAuthenticator.class);
                [given([facebookProvider identifier]) willReturn:kFBProviderId];
                twitterProvider = mock(A0BaseAuthenticator.class);
                [given([twitterProvider identifier]) willReturn:kTwitterProviderId];

                [authenticator registerAuthenticationProviders:@[facebookProvider, twitterProvider]];
            });
            
            itBehavesLike(@"registered provider", ^{ return @{ @"provider": facebookProvider }; });
            itBehavesLike(@"registered provider", ^{ return @{ @"provider": twitterProvider }; });
        });

    });

    describe(@"configuration with application info", ^{

        __block A0Application *application;
        __block A0Strategy *facebookStrategy;
        __block id<A0AuthenticationProvider> facebookProvider;
        __block id<A0AuthenticationProvider> twitterProvider;

        beforeEach(^{
            facebookProvider = mock(A0BaseAuthenticator.class);
            [given([facebookProvider identifier]) willReturn:kFBProviderId];
            twitterProvider = mock(A0BaseAuthenticator.class);
            [given([twitterProvider identifier]) willReturn:kTwitterProviderId];
            application = mock(A0Application.class);
            facebookStrategy = mock(A0Strategy.class);
            [given([facebookStrategy name]) willReturn:kFBProviderId];
            [authenticator registerAuthenticationProviders:@[facebookProvider, twitterProvider]];
        });

        context(@"has declared a registered provider", ^{

            it(@"should have application's strategy providers", ^{
                expect(authenticator.authenticators[facebookProvider.identifier]).to.equal(facebookProvider);
            });

            it(@"should not have undeclared provider", ^{
                expect(authenticator.authenticators[twitterProvider.identifier]).to.equal(twitterProvider);
            });

        });

    });

    describe(@"Authentication", ^{

        __block A0Strategy *strategy;
        __block id<A0AuthenticationProvider> provider;
        __block A0AuthParameters *parameters;
        void(^successBlock)(A0UserProfile *, A0Token *) = ^(A0UserProfile *profile, A0Token *token) {};

        beforeEach(^{
            strategy = mock(A0Strategy.class);
            provider = mock(A0BaseAuthenticator.class);
            [given([strategy name]) willReturn:@"provider"];
            [given([provider identifier]) willReturn:@"provider"];
            [authenticator registerAuthenticationProvider:provider];
            parameters = [A0AuthParameters newDefaultParams];
        });

        context(@"authenticate with known connection", ^{

            void(^failureBlock)(NSError *) = ^(NSError *error) {};
            beforeEach(^{
                [authenticator authenticateWithConnectionName:@"provider" parameters:parameters success:successBlock failure:failureBlock];
            });

            it(@"should call the correct provider", ^{
                MKTArgumentCaptor *captor = [[MKTArgumentCaptor alloc] init];
                [MKTVerify(provider) authenticateWithParameters:[captor capture] success:successBlock failure:failureBlock];
                A0AuthParameters *params = captor.value;
                expect(params[A0ParameterConnection]).to.equal(@"provider");
            });

        });

    });

    describe(@"Handle URL", ^{

        __block id<A0AuthenticationProvider> facebook;
        __block id<A0AuthenticationProvider> twitter;
        NSURL *facebookURL = [NSURL URLWithString:@"fb12345678://handler"];
        NSURL *twitterURL = [NSURL URLWithString:@"twitter://handler"];

        beforeEach(^{
            facebook = mock(A0BaseAuthenticator.class);
            twitter = mock(A0BaseAuthenticator.class);
            [given([facebook handleURL:facebookURL sourceApplication:nil]) willReturnBool:YES];
            [given([twitter handleURL:twitterURL sourceApplication:nil]) willReturnBool:YES];
            authenticator.authenticators = [@{ @"facebook": facebook, @"twitter": twitter } mutableCopy];
        });

        context(@"url for facebook provider to handle", ^{

            __block BOOL handled;

            beforeEach(^{
                handled = [authenticator handleURL:facebookURL sourceApplication:nil];
            });

            it(@"should call facebook provider", ^{
                [verifyCount(facebook, times(1)) handleURL:facebookURL sourceApplication:nil];
            });

            it(@"should be handled", ^{
                expect(handled).to.beTruthy();
            });
        });

        context(@"url for twitter provider to handle", ^{

            __block BOOL handled;

            beforeEach(^{
                handled = [authenticator handleURL:twitterURL sourceApplication:nil];
            });

            it(@"should call facebook provider", ^{
                [verifyCount(twitter, times(1)) handleURL:twitterURL sourceApplication:nil];
            });

            it(@"should be handled", ^{
                expect(handled).to.beTruthy();
            });
        });

        context(@"unknown url to handle", ^{

            __block BOOL handled;
            NSURL *invalidURL = [NSURL URLWithString:@"ftp://pepe"];

            beforeEach(^{
                handled = [authenticator handleURL:invalidURL sourceApplication:nil];
            });

            it(@"should call all providers", ^{
                [verifyCount(twitter, times(1)) handleURL:invalidURL sourceApplication:nil];
                [verifyCount(facebook, times(1)) handleURL:invalidURL sourceApplication:nil];
            });

            it(@"should be handled", ^{
                expect(handled).to.beFalsy();
            });
        });

    });

    describe(@"Clear sessions", ^{

        __block id<A0AuthenticationProvider> facebook;
        __block id<A0AuthenticationProvider> twitter;

        beforeEach(^{
            facebook = mock(A0BaseAuthenticator.class);
            twitter = mock(A0BaseAuthenticator.class);
            authenticator.authenticators = [@{ @"facebook": facebook, @"twitter": twitter } mutableCopy];
        });

        context(@"url for facebook provider to handle", ^{

            beforeEach(^{
                [authenticator clearSessions];
            });

            it(@"should call facebook provider", ^{
                [verifyCount(facebook, times(1)) clearSessions];
            });

            it(@"should call twitter provider", ^{
                [verifyCount(twitter, times(1)) clearSessions];
            });
        });

    });

});

SpecEnd

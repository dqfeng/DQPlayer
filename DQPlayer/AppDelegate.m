//
//  AppDelegate.m
//  DQPlayer
//
//  Created by dqfeng on 2018/2/8.
//  Copyright © 2018年 appfactory. All rights reserved.
//

#import "AppDelegate.h"
#import <objc/runtime.h>

@interface AppDelegate ()

@end

@implementation AppDelegate
- (BOOL)isAppUpdate
{
    return NO;
}

- (BOOL)isInstalled:(NSString *)bundleId {
    NSBundle *container = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/MobileContainerManager.framework"];
    if ([container load]) {
        Class appContainer = NSClassFromString(@"MCMAppContainer");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        id container = [appContainer performSelector:@selector(containerWithIdentifier:error:) withObject:bundleId withObject:nil];
#pragma clang diagnostic pop
//        NSLog(@"%@", [container performSelector:@selector(identifier)]);
        if (container) {
            return YES;
        } else {
            return NO;
        }
    }
    return NO;
}

- (void)getInstallApps
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    // do something
    

    Class LSApplicationWorkspace_class = (Class)objc_getClass("LSApplicationWorkspace");
//    Class LSApplicationWorkspace_class = NSClassFromString(@"LSApplicationWorkspace");
    unsigned int count;
    Method *methods = class_copyMethodList(LSApplicationWorkspace_class, &count);
    NSMutableArray *arr = @[].mutableCopy;
    for (int i = 0; i < count; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char * typeEncoding = method_getTypeEncoding(method);
        
        NSString *name = NSStringFromSelector(selector);
        [arr addObject:name];
    }
    NSLog(@"%@",arr);

    
    
    SEL selector    =   NSSelectorFromString(@"defaultWorkspace");
    NSObject* workspace = [LSApplicationWorkspace_class performSelector:selector];
    NSMethodSignature *sig = [workspace.class instanceMethodSignatureForSelector:@selector(applicationIsInstalled:)];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setTarget:workspace];
    NSString *appid = @"com.aotesiqi.zhongguotianqi";
    [invocation setArgument:&appid atIndex:2];
    [invocation setSelector:@selector(applicationIsInstalled:)];
    [invocation invoke];
//    NSUInteger length = [[invocation methodSignature] methodReturnLength];
    BOOL buffer;
    [invocation getReturnValue:&buffer];//        NSLog(@"isAppUpdate:%@",r);

    
    
    
    
    
    SEL selectorALL = NSSelectorFromString(@"allInstalledApplications");
    SEL ALL = NSSelectorFromString(@"allApplications");

    SEL selectorPlaceholder = NSSelectorFromString(@"placeholderApplications");
    SEL selectorUnrestricted = NSSelectorFromString(@"unrestrictedApplications");
    SEL selectorIsInstalled = NSSelectorFromString(@"applicationIsInstalled:");
    SEL selectorDirections = NSSelectorFromString(@"directionsApplications");
    SEL selectorType = NSSelectorFromString(@"applicationsOfType:");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    NSArray *all = [workspace performSelector:ALL];

    NSArray *allInstallApps = [workspace performSelector:selectorALL];
    NSArray *placeInstallApps = [workspace performSelector:selectorPlaceholder];
    NSArray *unrestrictedApps = [workspace performSelector:selectorUnrestricted];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"_bundleType = 'User'"];
    NSPredicate *blockPredicate = [NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        NSLog(@"");
        return true;
    }];
    sleep(10);
    [allInstallApps filteredArrayUsingPredicate:blockPredicate];
    NSArray *filterArr = [allInstallApps filteredArrayUsingPredicate:predicate];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    
    NSLog(@"%f", end - start);

    for (NSObject *app in filterArr) {
        
    }
//    while (true) {
//        NSArray *placeInstallApps = [workspace performSelector:selectorPlaceholder];
//
//        NSProgress *progress = [placeInstallApps.firstObject performSelector:@selector(installProgress)];
//        NSLog(@"%@",progress);
//        CGFloat p = progress.completedUnitCount/progress.totalUnitCount*0.1;
//        NSLog(@"progress:%@",@(p));
//        sleep(1);
//    }
    
    
    
    for (NSObject *obj in filterArr) {
        
        
        
        
        
        NSString *appBundleId   = [obj performSelector:@selector(applicationIdentifier)];
        NSNumber *installtype   = [obj valueForKey:@"_installType"];

//        while (true) {
//            NSLog(@"%@",installtype);
//            sleep(1);
//        }
        
        
//        if ([appBundleId isEqualToString:@"com.aotesiqi.zhongguotianqi"]) {
//            unsigned int count;
//            Method *methods = class_copyMethodList(obj.class, &count);
//            NSMutableArray *arr = @[].mutableCopy;
//            for (int i = 0; i < count; i++) {
//                Method method = methods[i];
//                SEL selector = method_getName(method);
//                const char * typeEncoding = method_getTypeEncoding(method);
//
//                NSString *name = NSStringFromSelector(selector);
//                [arr addObject:name];
//            }
//            NSLog(@"%@",arr);

//            @property (nonatomic, readonly, copy) NSString *bundleIdentifier;
//            @property (nonatomic, readonly) BOOL isAlwaysAvailable;
//            @property (nonatomic, readonly) BOOL isBlocked;
//            @property (nonatomic, readonly) BOOL isInstalled;
//            @property (nonatomic, readonly) BOOL isPlaceholder;
//            @property (nonatomic, readonly) BOOL isRemovedSystemApp;
//            @property (nonatomic, readonly) BOOL isRestricted;
//            @property (nonatomic, readonly) BOOL isValid;

            
//            id state = [obj performSelector:@selector(appState)];
//            id isInstalled = [obj performSelector:@selector(isInstalled)];
//            id isNewsstandApp = [obj performSelector:@selector(isNewsstandApp)];
//            id isPlaceholder = [obj performSelector:@selector(isPlaceholder)];

//            NSLog(@"state: %@", @"");
//        }
    }
//    NSLog(@"%@",workspace);
    for (NSObject *obj in filterArr) {
        NSString *appBundleId   = [obj performSelector:@selector(applicationIdentifier)];
        NSLog(@"app:%@",appBundleId);
//        NSNumber *installtype   = [obj valueForKey:@"_installType"];
//        NSNumber * orginInstalltype   = [obj valueForKey:@"_originalInstallType"];
//        NSMethodSignature *sig = [obj.class instanceMethodSignatureForSelector:@selector(isAppUpdate)];
//        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
//        [invocation setTarget:obj];
//        [invocation setSelector:@selector(isAppUpdate)];
//        [invocation invoke];
//        NSUInteger length = [[invocation methodSignature] methodReturnLength];
//        BOOL buffer;
//        [invocation getReturnValue:&buffer];//        NSLog(@"isAppUpdate:%@",r);
//        if (buffer) {
//            NSLog(@"app:%@ 更新",appBundleId);
//        }
//        if (installtype.integerValue != 0 || orginInstalltype.integerValue != 0) {
//            NSLog(@"app: %@ type:%@ originType:%@", appBundleId,installtype,orginInstalltype);
//        }
        if ([appBundleId isEqualToString:@"com.aotesiqi.zhongguotianqi"]) {
//            id state = [obj performSelector:@selector(appState)];
            unsigned int count;
            Method *methods = class_copyMethodList(obj.class, &count);
            NSMutableArray *arr = @[].mutableCopy;
            for (int i = 0; i < count; i++) {
                Method method = methods[i];
                SEL selector = method_getName(method);
                const char * typeEncoding = method_getTypeEncoding(method);
                
                NSString *name = NSStringFromSelector(selector);
                [arr addObject:name];
            }
            NSLog(@"%@",arr);

            NSLog(@"state: %@", @"");
        }
    }
#pragma clang diagnostic pop    // -Wundeclared-selector
#pragma clang diagnostic pop    // -Warc-performSelector-leaks
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    //com.weilizhang.InterestingNews2
    //com.aotesiqi.zhongguotianqi
//    [self getInstallApps];
//    BOOL s = [self isInstalled:@"com.aotesiqi.zhongguotianqi"];
//    NSLog(@"%@",s?@"已安装":@"未安装");
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end

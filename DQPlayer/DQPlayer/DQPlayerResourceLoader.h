//
//  DQPlayerResourceLoader.h
//  DQPlayer
//
//  Created by dqfeng on 2018/2/8.
//  Copyright © 2018年 appfactory. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface DQPlayerResourceLoader : NSObject<AVAssetResourceLoaderDelegate>

@property (nonatomic,readonly) NSString *cacheFilePath;

+ (instancetype)resourceLoaderWithCacheFilePath:(NSString *)cacheFilePath;

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath;

+ (void)removeCacheWithCacheFilePath:(NSString *)cacheFilePath;


@end

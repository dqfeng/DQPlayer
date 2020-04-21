//
//  DQPlayerResourceLoaderTask.h
//  DQPlayer
//
//  Created by dqfeng on 2019/3/7.
//  Copyright © 2019年 appfactory. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DQPlayerCacheFile.h"
@class AVAssetResourceLoadingRequest;
@class DQPlayerCacheFile;
@class DQPlayerResourceLoadTask;
typedef void (^DQPlayerResourceLoadTaskFinishedBlock)(DQPlayerResourceLoadTask *task,NSError *error);

@interface DQPlayerResourceLoadTask : NSObject

@property (readonly, nonatomic, getter = isExecuting) BOOL executing;
@property (readonly, nonatomic, getter = isFinished)  BOOL finished;
@property (readonly, nonatomic, getter = isCancelled) BOOL cancelled;
@property (nonatomic,readonly)   AVAssetResourceLoadingRequest *loadingRequest;
@property (nonatomic,readonly)   DQPlayerCacheFile * cacheFile;
@property (nonatomic,assign)     NSRange range;
@property (nonatomic,copy)       DQPlayerResourceLoadTaskFinishedBlock finishBlock;


- (instancetype)initWithCacheFile:(DQPlayerCacheFile *)cacheFile loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range;

- (void)startLoad;
- (void)cancel;

@end

@interface DQPlayerLocalResourceLoadTask: DQPlayerResourceLoadTask

@end

@interface DQPlayerRemoteResourceLoadTask: DQPlayerResourceLoadTask

@property (nonatomic,strong)     NSHTTPURLResponse *response;

@end

//
//  DQPlayerResourceLoader.m
//  DQPlayer
//
//  Created by dqfeng on 2018/2/8.
//  Copyright © 2018年 appfactory. All rights reserved.
//

#import "DQPlayerResourceLoader.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "DQPlayerCacheFile.h"
#import "DQPlayerUtils.h"
#import "DQPlayerResourceLoadTask.h"

@interface DQPlayerResourceLoader ()<NSURLSessionDelegate>

@property (nonatomic,strong) NSString *cacheFilePath;
@property (nonatomic,strong) NSMutableArray<AVAssetResourceLoadingRequest *> *pendingRequests;
@property (nonatomic,strong) AVAssetResourceLoadingRequest *currentRequest;
@property (nonatomic,assign) NSRange currentDataRange;
@property (nonatomic,strong) NSHTTPURLResponse *response;
@property (nonatomic,strong) DQPlayerCacheFile *cacheFile;
@property (nonatomic,strong) DQPlayerResourceLoadTask *currentResourceLoadTask;
@property (nonatomic,strong) NSMutableArray<DQPlayerResourceLoadTask *> *loadingTasks;

@end

@implementation DQPlayerResourceLoader

- (void)dealloc
{
    [self.loadingTasks enumerateObjectsUsingBlock:^(DQPlayerResourceLoadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
    [_cacheFile synchronize];
}

+ (void)removeCacheWithCacheFilePath:(NSString *)cacheFilePath
{
    [[NSFileManager defaultManager] removeItemAtPath:cacheFilePath error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[cacheFilePath stringByAppendingString:[DQPlayerCacheFile indexFileExtension]] error:NULL];
}

+ (instancetype)resourceLoaderWithCacheFilePath:(NSString *)cacheFilePath
{
    return [[self alloc] initWithCacheFilePath:cacheFilePath];
}

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath
{
    self = [super init];
    if (self) {
        _cacheFile = [DQPlayerCacheFile cacheFileWithFilePath:cacheFilePath];
        if (!_cacheFile) {
            return nil;
        }
        _pendingRequests = [[NSMutableArray alloc] init];
        _loadingTasks = [[NSMutableArray alloc] init];
        _currentDataRange = DQInvalidRange;
    }
    return self;
}

- (NSString *)cacheFilePath
{
    return _cacheFile.cacheFilePath;
}

#pragma mark - loading request
- (void)startNextRequest
{
    if (_currentRequest || _pendingRequests.count == 0) {
        return;
    }

    _currentRequest = [_pendingRequests firstObject];

    //data range
    if (@available(iOS 9.0, *)) {
        if ([_currentRequest.dataRequest respondsToSelector:@selector(requestsAllDataToEndOfResource)] && _currentRequest.dataRequest.requestsAllDataToEndOfResource) {
            _currentDataRange = NSMakeRange((NSUInteger)_currentRequest.dataRequest.requestedOffset, NSUIntegerMax);
        }
        else {
            _currentDataRange = NSMakeRange((NSUInteger)_currentRequest.dataRequest.requestedOffset, _currentRequest.dataRequest.requestedLength);
        }
    } else {
        _currentDataRange = NSMakeRange((NSUInteger)_currentRequest.dataRequest.requestedOffset, _currentRequest.dataRequest.requestedLength);
    }

    //response
    if (!_response && _cacheFile.responseHeaders.count > 0) {
        if (_currentDataRange.length == NSUIntegerMax) {
            _currentDataRange.length = [_cacheFile fileLength] - _currentDataRange.location;
        }
        
        NSMutableDictionary *responseHeaders = [_cacheFile.responseHeaders mutableCopy];
        NSString *contentRangeKey = @"Content-Range";
        BOOL supportRange = responseHeaders[contentRangeKey] != nil;
        if (supportRange && DQValidByteRange(_currentDataRange)) {
            responseHeaders[contentRangeKey] = DQRangeToHTTPRangeReponseHeader(_currentDataRange, [_cacheFile fileLength]);
        }
        else {
            [responseHeaders removeObjectForKey:contentRangeKey];
        }
        responseHeaders[@"Content-Length"] = [NSString stringWithFormat:@"%tu",_currentDataRange.length];

        NSInteger statusCode = supportRange ? 206 : 200;
        _response = [[NSHTTPURLResponse alloc] initWithURL:_currentRequest.request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:responseHeaders];
        [DQPlayerUtils avAssetResourceLoadingRequest:_currentRequest fillContentInformation:_response];
    }
    [self startCurrentRequest];
}

- (void)startCurrentRequest
{
    if (_currentDataRange.length == NSUIntegerMax) {
        [self addTaskWithRange:NSMakeRange(_currentDataRange.location, NSUIntegerMax) cached:NO];
    }
    else {
        NSUInteger start = _currentDataRange.location;
        NSUInteger end = NSMaxRange(_currentDataRange);
        while (start < end) {
            NSRange firstNotCachedRange = [_cacheFile firstNotCachedRangeFromPosition:start];
            if (!DQValidFileRange(firstNotCachedRange)) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:_cacheFile.cachedDataBound > 0];
                start = end;
            }
            else if (firstNotCachedRange.location >= end) {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            }
            else if (firstNotCachedRange.location >= start) {
                if (firstNotCachedRange.location > start) {
                    [self addTaskWithRange:NSMakeRange(start, firstNotCachedRange.location - start) cached:YES];
                }
                NSUInteger notCachedEnd = MIN(NSMaxRange(firstNotCachedRange), end);
                [self addTaskWithRange:NSMakeRange(firstNotCachedRange.location, notCachedEnd - firstNotCachedRange.location) cached:NO];
                start = notCachedEnd;
            }
            else {
                [self addTaskWithRange:NSMakeRange(start, end - start) cached:YES];
                start = end;
            }
        }
    }
}

- (void)addTaskWithRange:(NSRange)range cached:(BOOL)cached
{
    DQPlayerResourceLoadTask *task = nil;
    if (cached) {
        task = [[DQPlayerLocalResourceLoadTask alloc] initWithCacheFile:_cacheFile loadingRequest:_currentRequest range:range];
    }
    else {
        task = [[DQPlayerRemoteResourceLoadTask alloc] initWithCacheFile:_cacheFile loadingRequest:_currentRequest range:range];
        [(DQPlayerRemoteResourceLoadTask *)task setResponse:_response];
    }
    __weak typeof(self) weakSelf = self;
    task.finishBlock = ^(DQPlayerResourceLoadTask *task, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (task.cancelled || error.code == NSURLErrorCancelled) {
                [strongSelf.loadingTasks removeObject:task];
                return;
            }
            if (error) {
                [strongSelf currentRequestFinished:error];
            }
            else {
                if (strongSelf.loadingTasks.count == 1) {
                    [strongSelf currentRequestFinished:nil];
                }
            }
            strongSelf.currentResourceLoadTask = nil;
            [strongSelf.loadingTasks removeObject:task];
        });
    };
    [self.loadingTasks addObject:task];
    [task startLoad];
}

- (void)cancelCurrentRequest:(BOOL)finishCurrentRequest
{
    [self.loadingTasks enumerateObjectsUsingBlock:^(DQPlayerResourceLoadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj cancel];
    }];
    if (finishCurrentRequest) {
        if (_currentRequest && !_currentRequest.isFinished) {
            NSLog(@"%s--%@",__func__,@"cancel currentrequest no finish");
            [self currentRequestFinished:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
        }
    }
    else {
        [self cleanUpCurrentRequest];
    }
}

- (void)currentRequestFinished:(NSError *)error
{
    NSLog(@"%s",__func__);
    if (error) {
        [_currentRequest finishLoadingWithError:error];
    }
    else {
        [_currentRequest finishLoading];
    }
    [self cleanUpCurrentRequest];
    [self startNextRequest];
}

- (void)cleanUpCurrentRequest
{
    [_pendingRequests removeObject:_currentRequest];
    _currentRequest = nil;
    _response = nil;
    _currentDataRange = DQInvalidRange;
}

#pragma mark - resource loader delegate
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"%s--%@",__func__,loadingRequest);
    [self cancelCurrentRequest:YES];
    [_pendingRequests addObject:loadingRequest];
    [self startNextRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"%s--%@",__func__,loadingRequest);
    if (_currentRequest == loadingRequest) {
        [self cancelCurrentRequest:NO];
    }
    else {
        [_pendingRequests removeObject:loadingRequest];
    }
}

@end

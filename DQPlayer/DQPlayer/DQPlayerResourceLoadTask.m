//
//  DQPlayerResourceLoaderTask.m
//  DQPlayer
//
//  Created by dqfeng on 2019/3/7.
//  Copyright © 2019年 appfactory. All rights reserved.
//

#import "DQPlayerResourceLoadTask.h"
#import "DQPlayerCacheFile.h"
#import "DQPlayerUtils.h"


static dispatch_queue_t WorkQueue(){
    static dispatch_once_t onceToken;
    static dispatch_queue_t queue = nil;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("dqplayer_load", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@interface DQPlayerResourceLoadTask ()

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished)  BOOL finished;
@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;

@end

@implementation DQPlayerResourceLoadTask

- (instancetype)initWithCacheFile:(DQPlayerCacheFile *)cacheFile loadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest range:(NSRange)range
{
    self = [super init];
    if (self) {
        _loadingRequest = loadingRequest;
        _range = range;
        _cacheFile = cacheFile;
    }
    return self;
}

- (void)startLoad
{
    
}

- (void)cancel
{
    
}


@end

@interface DQPlayerLocalResourceLoadTask ()


@end

@implementation DQPlayerLocalResourceLoadTask

- (void)startLoad
{
    dispatch_async(WorkQueue(), ^{
        if ([self isCancelled]) {
            [self handleFinished];
            return;
        }
        
        [self setExecuting:YES];
        NSUInteger offset = self.range.location;
        NSUInteger lengthPerRead = 1024*1024;
        while (offset < NSMaxRange(self.range)) {
            if ([self isCancelled]) {
                break;
            }
            @autoreleasepool {
                NSRange range = NSMakeRange(offset, MIN(NSMaxRange(self.range) - offset,lengthPerRead));
                NSData *data = [self.cacheFile dataWithRange:range];
                [self.loadingRequest.dataRequest respondWithData:data];
                offset = NSMaxRange(range);
            }
        }
        [self handleFinished];
    });
}

- (void)handleFinished
{
    [self setExecuting:NO];
    [self setFinished:YES];
    if (self.finishBlock) {
        self.finishBlock(self,nil);
    }
}

- (void)cancel
{
    self.cancelled = YES;
}

@end

@interface DQPlayerRemoteResourceLoadTask () <NSURLSessionDelegate, NSURLSessionDataDelegate>

@property (assign, nonatomic) NSUInteger offset;
@property (assign, nonatomic) NSUInteger requestLength;
@property (assign, nonatomic) BOOL dataSaved;
@property (strong, nonatomic) NSError *error;
@property (strong, nonatomic) NSURLSessionConfiguration *sessionConfiguration;
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) NSURLSessionDataTask *sessionDataTask;

@end

@implementation DQPlayerRemoteResourceLoadTask

- (void)startLoad
{
    dispatch_async(WorkQueue(), ^{
        if ([self isCancelled]) {
            [self handleFinished];
            return;
        }
        [self setExecuting:YES];
        NSMutableURLRequest *urlRequest = [self.loadingRequest.request mutableCopy];
        urlRequest.URL = [DQPlayerUtils originalURLFromCacheSupportURL:self.loadingRequest.request.URL];
        urlRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
        self.offset = 0;
        self.requestLength = 0;
        if (!(self.response && ![DQPlayerUtils isSupportRangeOfHTTPURLResponse:self.response])) {
            NSString *rangeValue = DQRangeToHTTPRangeHeader(self.range);
            if (rangeValue) {
                [urlRequest setValue:rangeValue forHTTPHeaderField:@"Range"];
                self.offset = self.range.location;
                self.requestLength = self.range.length;
            }
        }
        
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 1;
        queue.name = @(self.range.location).stringValue;
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                 delegate:self
                                            delegateQueue:queue];
        self.sessionDataTask = [self.session dataTaskWithRequest:urlRequest];
        [self.sessionDataTask resume];
    });
}

- (void)handleFinished
{
    [self setExecuting:NO];
    [self setFinished:YES];
    if (self.finishBlock) {
        self.finishBlock(self,_error);
    }
}

- (void)cancel
{
    if (!self.cancelled) {
        if (self.session) {
            [self.sessionDataTask cancel];
            [self.session invalidateAndCancel];
        }
        self.cancelled = YES;
    }
}

- (void)synchronizeCacheFileIfNeeded
{
    if (_dataSaved) {
        [self.cacheFile synchronize];
    }
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    dispatch_async(WorkQueue(), ^{
        if (response) {
            self.loadingRequest.redirect = request;
        }
        if(completionHandler){
            completionHandler(request);
        }

    });
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    dispatch_async(WorkQueue(), ^{
        if (self.response || !response) {
            if (completionHandler) {
                completionHandler(NSURLSessionResponseAllow);
            }
            return;
        }
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            self.response = (NSHTTPURLResponse *)response;
            [self.cacheFile setResponse:self.response];
            [DQPlayerUtils avAssetResourceLoadingRequest:self.loadingRequest fillContentInformation:self.response];
        }
        
        if (![DQPlayerUtils isSupportRangeOfHTTPURLResponse:self.response]) {
            self.offset = 0;
        }
        if (self.offset == NSUIntegerMax) {
            self.offset = (NSUInteger)[DQPlayerUtils fileLengthOfHTTPURLResponse:self.response] - self.requestLength;
        }
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    });
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    dispatch_async(WorkQueue(), ^{
        if (data && data.length > 0 && data.bytes && [self.cacheFile saveData:data atOffset:self.offset synchronize:YES]) {
            self.dataSaved = YES;
            self.offset += [data length];
            [self.loadingRequest.dataRequest respondWithData:data];
        }
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    dispatch_async(WorkQueue(), ^{
        if (!error) {
            [self synchronizeCacheFileIfNeeded];
        }
        else {
            [self synchronizeCacheFileIfNeeded];
            self.error = error;
            if (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorTimedOut || error.code == NSURLErrorNetworkConnectionLost) {
                
            }
//            NSLog(@"%s----%@",__func__,error.localizedDescription);
        }
        [self handleFinished];
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
downloadCompletionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))downloadCompletionHandler {
    
    
}

@end

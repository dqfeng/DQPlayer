//
//  DQPlayer.m
//  DQPlayer
//
//  Created by dqfeng on 2018/2/8.
//  Copyright © 2018年 appfactory. All rights reserved.
//

#import "DQPlayer.h"
#import "DQPlayerResourceLoader.h"
#import "DQPlayerUtils.h"

@interface DQPlayer ()

@property (nonatomic,assign) DQPlayerState  state;
@property (nonatomic,assign) NSUInteger duration;
@property (nonatomic,assign) NSUInteger currentTime;
@property (nonatomic,assign) CGFloat loadProgress;
@property (nonatomic,strong) CALayer *playerLayer;
@property (nonatomic,strong) AVPlayer *player;
@property (nonatomic,strong) NSObject *playbackTimeObserver;
@property (nonatomic,strong) DQPlayerResourceLoader *resourceLoader;
@property (nonatomic,assign) BOOL  pausedByUser;
@property (nonatomic,assign) BOOL  isSeeking;
@property (nonatomic,assign) BOOL  pausedByUserWhenSeeking;
@property (nonatomic,assign) BOOL  failedRetrying;
@property (nonatomic,strong) NSURL  * url;;

@end

@implementation DQPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _state = DQPlayerStateStoped;
    }
    return self;
}

- (void)playWithUrl:(NSURL *)url
{
    [self stop];
    self.state = DQPlayerStateBuffering;
    self.url = url;
    NSURL *resourceURL = [DQPlayerUtils cacheSupportURLFromURL:url];
    AVPlayerItem *playerItem = nil;
    if ([[UIDevice currentDevice] systemVersion].floatValue < 7.0 || [resourceURL.scheme isEqualToString:@"file"]) {
        playerItem = [AVPlayerItem playerItemWithURL:resourceURL];
    }
    else {
        NSString * cacheFilePath = [[[NSTemporaryDirectory() stringByAppendingPathComponent:kDQPlayerCacheSubDirectoryName] stringByAppendingPathComponent:[DQPlayerUtils md5OfString:[url absoluteString]]] stringByAppendingPathExtension:[url pathExtension]];
        NSLog(@"%@", cacheFilePath);
        self.resourceLoader = [DQPlayerResourceLoader resourceLoaderWithCacheFilePath:cacheFilePath];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:resourceURL options:nil];
        [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
//        playerItem= [AVPlayerItem playerItemWithAsset:asset];
        playerItem = [[AVPlayerItem alloc] initWithURL:url];
    }
    if (!self.player) {
        self.player = [AVPlayer playerWithPlayerItem:playerItem];
        self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    }
    else {
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemFailedToPlayToEndTimeNotificationHandle:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemFailedToPlayToEndTimeNotificationHandle:) name:AVPlayerItemNewErrorLogEntryNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemFailedToPlayToEndTimeNotificationHandle:) name:AVPlayerItemNewErrorLogEntryNotification object:nil];
}

- (void)playerItemFailedToPlayToEndTimeNotificationHandle:(NSNotification *)notification
{
    NSDictionary *userInfo = notification.userInfo;
    AVPlayerItemErrorLog *log = self.player.currentItem.errorLog;
    NSError *error = self.player.currentItem.error;
    NSLog(@"%@",[[NSString alloc] initWithData:[log extendedLogData] encoding:[log extendedLogDataStringEncoding]]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    AVPlayerItem *playerItem = self.player.currentItem;
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = playerItem.status;
        if (status == AVPlayerStatusReadyToPlay) {
            NSTimeInterval totalDuration = CMTimeGetSeconds(playerItem.duration);
            self.duration = totalDuration;
            self.currentTime = 0;
            self.state = DQPlayerStateReadytoplay;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.currentTime > 1) {
                    [self seekToTime:self.currentTime];
                }
                else {
                    self.failedRetrying = NO;
                }
            });
            [self startMonitoringPlayback:playerItem];
            NSLog(@"play:%@",@"readytoplay");
        }
        else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            NSLog(@"%s---:%@",__func__,playerItem.error);
            self.state = DQPlayerStateError;
            if (self.failedRetryCount > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.failedRetryCount = self.failedRetryCount - 1;
                    if (self.state != DQPlayerStateStoped) {
                        self.failedRetrying = YES;
                        [self playWithUrl:self.url];
                    }
                });
            }
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        [self calculateLoadProgress:playerItem];
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        NSLog(@"playerItem.isPlaybackBufferEmpty:%@",@(playerItem.isPlaybackBufferEmpty));
        if (playerItem.isPlaybackBufferEmpty) {
            if (!self.pausedByUser) {
                if (self.player.rate != 0) {
                    [self.player pause];
                }
                self.state = DQPlayerStateBuffering;
            }
        }
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        NSLog(@"playbackLikelyToKeepUp:%@",@(playerItem.isPlaybackLikelyToKeepUp));
        if (playerItem.isPlaybackLikelyToKeepUp) {
            
        }
    }
}

- (void)startMonitoringPlayback:(AVPlayerItem *)playerItem
{
    self.duration = (NSUInteger)(playerItem.duration.value / playerItem.duration.timescale); //视频总时间
    if (!self.pausedByUser) {
        [self.player play];
    }
    if (self.playbackTimeObserver) {
        [self.player removeTimeObserver:self.playbackTimeObserver];
        self.playbackTimeObserver = nil;
    }
    __weak __typeof(self)weakSelf = self;
    self.playbackTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        CGFloat currentTime = playerItem.currentTime.value/playerItem.currentTime.timescale;
        if (!strongSelf.pausedByUser && strongSelf.player.rate) {
            strongSelf.state = DQPlayerStatePlaying;
        }
        if (strongSelf.currentTime != currentTime) {
            strongSelf.currentTime = currentTime;
            if (strongSelf.currentTime > strongSelf.duration) {
                strongSelf.duration = strongSelf.currentTime;
            }
            if (strongSelf.progressChanged) {
                strongSelf.progressChanged(strongSelf);
            }
        }
    }];
}

- (void)calculateLoadProgress:(AVPlayerItem *)playerItem
{
    if (self.loadProgress >= 1) return;
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
    CMTime duration = playerItem.duration;
    NSTimeInterval totalDuration = CMTimeGetSeconds(duration);
    NSTimeInterval currentTime = CMTimeGetSeconds(playerItem.currentTime);
    NSTimeInterval temp = 0;
    if (currentTime < totalDuration - 2) {
        temp = 3;
    }
    else if (currentTime == totalDuration - 2){
        temp = 2;
    }
    else if (currentTime == totalDuration - 1){
        temp = 1;
    }
    else if (currentTime == totalDuration){
        temp = 0;
    }
    if (timeInterval < currentTime + temp) {
        if (!self.pausedByUser) {
            self.state = DQPlayerStateBuffering;
            [self.player pause];
        }
    }
    else {
        if (!self.pausedByUser) {
            if (self.state != DQPlayerStatePlaying && !self.isSeeking) {
                self.state = DQPlayerStatePlaying;
            }
            [self.player play];
        }
    }
    self.loadProgress = timeInterval / totalDuration;
    if (self.loadProgressChanged) {
        self.loadProgressChanged(self);
    }
}

#pragma mark- player control
- (void)pause
{
    if (self.state == DQPlayerStateStoped) return;
    if (self.player) {
        self.player.rate = 0.0;
        self.state = DQPlayerStatePaused;
        self.pausedByUser = YES;
    }
}

- (void)play
{
    if (self.state == DQPlayerStateStoped) return;
    if (self.player) {
        self.player.rate = 1.0;
        self.pausedByUser = NO;
        self.state = DQPlayerStatePlaying;
        if (!self.player.currentItem.isPlaybackLikelyToKeepUp) {
            self.state = DQPlayerStateBuffering;
        }
    }
}

- (void)playOrPause
{
    if (self.state == DQPlayerStateStoped) return;
    if (self.state == DQPlayerStatePlaying || self.state == DQPlayerStateBuffering) {
        if (self.isSeeking) {
            self.pausedByUserWhenSeeking = YES;
        }
        [self pause];
    }
    else {
        self.pausedByUserWhenSeeking = NO;
        [self play];
    }
}

- (void)seekToTime:(CGFloat)seconds
{
    if (self.state == DQPlayerStateStoped || self.state == DQPlayerStateSeeking) return;
    seconds = MAX(0, seconds);
    seconds = MIN(seconds, self.duration);
    self.isSeeking = YES;
    [self.player pause];
    self.state = DQPlayerStateSeeking;
    [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
        NSLog(@"seek:%@",@(finished));
        if (finished) {
            if (!self.failedRetrying) {
                [self play];
            }
            if (!self.pausedByUserWhenSeeking && self.pausedByUser) {
                self.pausedByUser = NO;
            }
            if (!self.player.currentItem.isPlaybackLikelyToKeepUp) {
                self.state = DQPlayerStateBuffering;
            }
            self.isSeeking = NO;
            self.failedRetrying = NO;
        }
    }];
}

- (void)stop
{
    if (self.player) {
        [self.player pause];
        self.duration = 0;
        self.loadProgress = 0;
        self.state = DQPlayerStateStoped;
        self.currentTime = 0;
        self.pausedByUser = NO;
        [self.player.currentItem removeObserver:self forKeyPath:@"status"];
        [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [self.player removeTimeObserver:self.playbackTimeObserver];
        self.resourceLoader = nil;
        self.player = nil;
    }
}

#pragma mark- getter & setter
- (void)setState:(DQPlayerState)state
{
    if (_state != state) {
        _state = state;
        if (self.stateChanged) {
            self.stateChanged(self);
        }
    }
}

- (CGFloat)progress
{
    if (self.duration > 0) {
        return self.currentTime/self.duration;
    }
    return 0;
}

+ (NSString *)timeStringWithSeconds:(double)seconds
{
    NSInteger hour = seconds / 3600;
    NSInteger minute = (seconds - 3600 * hour) / 60;
    NSInteger second = (seconds - 3600 * hour - 60 * minute);
    NSString *timeStr;
    if (hour == 0) {
        timeStr = [NSString stringWithFormat:@"%02ld:%02ld",(long)minute,(long)second];
    }
    else {
        timeStr = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hour,(long)minute,(long)second];
    }
    return timeStr;
}


@end

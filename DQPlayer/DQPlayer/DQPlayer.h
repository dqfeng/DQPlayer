//
//  DQPlayer.h
//  DQPlayer
//
//  Created by dqfeng on 2018/2/8.
//  Copyright © 2018年 appfactory. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
typedef NS_ENUM(NSUInteger, DQPlayerState) {
    DQPlayerStateReadytoplay,
    DQPlayerStatePlaying,
    DQPlayerStateBuffering,
    DQPlayerStatePaused,
    DQPlayerStateSeeking,
    DQPlayerStateError,
    DQPlayerStateStoped
};

@interface DQPlayer : NSObject

@property (nonatomic,readonly) DQPlayerState  state;
@property (nonatomic,readonly) NSUInteger duration;
@property (nonatomic,readonly) NSUInteger currentTime;
@property (nonatomic,readwrite) NSUInteger failedRetryCount;
@property (nonatomic,readonly) CGFloat loadProgress;
@property (nonatomic,readonly) CALayer *playerLayer;
@property (nonatomic,readonly) BOOL buffering;
@property (nonatomic,strong)   void(^stateChanged)(DQPlayer *player);
@property (nonatomic,strong)   void(^progressChanged)(DQPlayer *player);
@property (nonatomic,strong)   void(^loadProgressChanged)(DQPlayer *player);

- (void)playWithUrl:(NSURL *)url;
- (void)pause;
- (void)play;
- (void)playOrPause;
- (void)stop;
- (void)seekToTime:(CGFloat)seconds;

+ (NSString *)timeStringWithSeconds:(double)seconds;

@end

//
//  ViewController.m
//  DQPlayer
//
//  Created by dqfeng on 2018/2/8.
//  Copyright © 2018年 appfactory. All rights reserved.
//

#import "ViewController.h"
#import "DQPlayer.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (strong, nonatomic) IBOutlet UIProgressView *loadProgressView;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (nonatomic) DQPlayer *player;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *bufferingActivityIndicatorView;
@end

@implementation ViewController


- (void)progressSliderDidChanged:(UISlider *)sender
{
    [self.player seekToTime:sender.value];
}

- (IBAction)playButtonAction:(UIButton *)sender
{
    [self.player playOrPause];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.progressSlider.enabled = NO;
    [self.progressSlider addTarget:self action:@selector(progressSliderDidChanged:) forControlEvents:UIControlEventTouchUpInside];
    [self.progressSlider addTarget:self action:@selector(progressSliderDidChanged:) forControlEvents:UIControlEventTouchUpOutside];
    [self.progressSlider addTarget:self action:@selector(progressSliderDidChanged:) forControlEvents:UIControlEventTouchCancel];

    //https://devstreaming-cdn.apple.com/videos/wwdc/2017/808qnk3ctygo5hd/808/hls_vod_mvp.m3u8
    //http://v4ttyey-10001453.video.myqcloud.com/Microblog/288-4-1452304375video1466172731.mp4
    //http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4
    // Do any additional setup after loading the view, typically from a nib.
    [self.playButton setTitle:@"播放" forState:UIControlStateNormal];
    [self.playButton setTitle:@"暂停" forState:UIControlStateSelected];
    [self startPlay];
}

- (void)startPlay
{
    self.player = [DQPlayer new];
    //http://203.187.160.133:9011/devstreaming.apple.com/c3pr90ntc0td/videos/wwdc/2014/210xxksa9s9ewsa/210/210_sd_accessibility_on_ios.mov
    //http://mvvideo2.meitudata.com/576bc2fc91ef22121.mp4
//    http://www.w3school.com.cn/example/html5/mov_bbb.mp4
    
    NSURL *url = [NSURL URLWithString:@"http://www.w3school.com.cn/example/html5/mov_bbb.mp4"];
    //http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4
    [self.player playWithUrl:url];
    [self.playerView.layer addSublayer:self.player.playerLayer];
    __typeof(self) weakSelf = self;
    self.player.stateChanged = ^(DQPlayer *player) {
        weakSelf.currentTimeLabel.text = [DQPlayer timeStringWithSeconds:player.currentTime];
        weakSelf.durationLabel.text = [DQPlayer timeStringWithSeconds:player.duration];
        if (player.state == DQPlayerStateReadytoplay) {
            if (!weakSelf.progressSlider.enabled) {
                weakSelf.progressSlider.enabled = YES;
            }
            [weakSelf.bufferingActivityIndicatorView startAnimating];
        }
        if (player.state == DQPlayerStateSeeking && weakSelf.progressSlider.value > player.loadProgress*player.duration) {
            [weakSelf.bufferingActivityIndicatorView startAnimating];
        }
        if (player.state == DQPlayerStateBuffering) {
            [weakSelf.bufferingActivityIndicatorView startAnimating];
        }
        else {
            [weakSelf.bufferingActivityIndicatorView stopAnimating];
        }
        if (player.state == DQPlayerStatePlaying) {
            weakSelf.playButton.selected = YES;
        }
        else if (player.state == DQPlayerStatePaused) {
            weakSelf.playButton.selected = NO;
        }
        else if (player.state == DQPlayerStateStoped) {
            weakSelf.playButton.selected = NO;
        }
    };
    
    self.player.progressChanged = ^(DQPlayer *player) {
        weakSelf.currentTimeLabel.text = [DQPlayer timeStringWithSeconds:player.currentTime];
        weakSelf.durationLabel.text = [DQPlayer timeStringWithSeconds:player.duration];
        weakSelf.progressSlider.minimumValue = 0;
        if (player.duration > 0) {
            weakSelf.progressSlider.maximumValue = player.duration;
            weakSelf.progressSlider.value = player.currentTime;
        }
    };
    
    self.player.loadProgressChanged = ^(DQPlayer *player) {
        weakSelf.loadProgressView.progress = player.loadProgress;
    };
    [self.bufferingActivityIndicatorView startAnimating];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    self.player.playerLayer.frame = self.playerView.bounds;
    [self.playerView bringSubviewToFront:self.bufferingActivityIndicatorView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)stop:(UIButton *)sender {
    [_player stop];
    [self startPlay];
}



@end

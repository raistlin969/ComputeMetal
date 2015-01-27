//
//  ViewController.m
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import "MetalViewController.h"
#import "MetalView.h"
#import "Renderer.h"

#import <QuartzCore/CAMetalLayer.h>

@implementation MetalViewController
{
    @private
    //app control
    CADisplayLink *_timer;

    //boolean to determine if the first draw has occured
    BOOL _firstDrawOccured;

    CFTimeInterval _timeSinceLastDrawPreviousTime;

    //pause/resume
    BOOL _gameLoopPaused;

    //renderer instance
    Renderer *_renderer;

    float _previousX;
    float _previousY;
}

-( void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    if(_timer)
    {
        [self stopGameLoop];
    }
}

- (void)initCommon
{
    _renderer = [Renderer new];
    self.metalViewControllerDelegate = _renderer;

    //register notifications to start/stop drawing as this app moves into the background
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    _interval = 1;
}

- (id)init
{
    self = [super init];
    if(self)
    {
        [self initCommon];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if(self)
    {
        [self initCommon];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        [self initCommon];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    MetalView *metalView = (MetalView *)self.view;
    metalView.metalViewDelegate = _renderer;

    //load all render assests before starting game loop
    [_renderer configure:metalView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//the main game loopcalled by the timer below
- (void)gameLoop
{
    //tell our delegate to update itself here
    [_metalViewControllerDelegate update:self];

    if(!_firstDrawOccured)
    {
        //set up timing data for display since this is the first time through this loop
        _timeSinceLastDraw = 0.0;
        _timeSinceLastDrawPreviousTime = CACurrentMediaTime();
        _firstDrawOccured = YES;
    }
    else
    {
        //figure out time since last draw
        CFTimeInterval currentTime = CACurrentMediaTime();

        _timeSinceLastDraw = currentTime - _timeSinceLastDrawPreviousTime;

        //keep track of the time interval between draws
        _timeSinceLastDrawPreviousTime = currentTime;
    }

    //display (render)

    assert([self.view isKindOfClass:[MetalView class]]);

    //call the display method directly on the render view (setNeedsDisplay: has been disabled in the renderview by default
    [(MetalView *)self.view display];
}

- (void)dispatchGameLoop
{
    //create a game loop timer using a display link
    _timer = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(gameLoop)];

    _timer.frameInterval = _interval;
    [_timer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)stopGameLoop
{
    if(_timer)
        [_timer invalidate];
}

- (void)setPaused:(BOOL)pause
{
    if(_gameLoopPaused == pause)
    {
        return;
    }

    if(_timer)
    {
        //inform the delegate we are about to pause
        [_metalViewControllerDelegate viewController:self willPause:pause];

        if(pause == YES)
        {
            _gameLoopPaused = pause;
            _timer.paused = YES;

            [(MetalView *)self.view releaseTextures];
        }
        else
        {
            _gameLoopPaused = pause;
            _timer.paused = NO;
        }
    }
}

- (BOOL)paused
{
    return _gameLoopPaused;
}

- (void)didEnterBackground:(NSNotification *)notification
{
    [self setPaused:YES];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    [self setPaused:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    //run game loop
    [self dispatchGameLoop];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    //end game loop
    [self stopGameLoop];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDidRecognize:)];

    [self.view addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panDidRecognize:)];
    pan.minimumNumberOfTouches = 1;
    pan.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:pan];

    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchDidRecognize:)];
    [self.view addGestureRecognizer:pinch];
}

- (void)tapDidRecognize:(UITapGestureRecognizer *)tap
{
    MetalView *mv = (MetalView *)self.view;
    mv.changeColors = YES;
}

- (void)pinchDidRecognize:(UIPinchGestureRecognizer *)pinch
{
    MetalView *view = (MetalView *)self.view;

    if(pinch.scale < 1.0)
        view.zoom *= 1.05;
    else
        view.zoom /= 1.05;
}

- (void)panDidRecognize:(UIPanGestureRecognizer *)pan
{
    CGPoint translatedPoint = [pan translationInView:self.view];
    MetalView *view = (MetalView *)self.view;
    float panSesitivity = (float)log(view.zoom + 1);
    if(pan.state == UIGestureRecognizerStateBegan)
    {
        _previousX = view.panX;
        _previousY = view.panY;
    }
    else
    {
//        res = ( src - src_min ) / ( src_max - src_min ) * ( res_max - res_min ) + res_min
        float x = (translatedPoint.x / view.bounds.size.width * 2.0) * panSesitivity;
        float y = (translatedPoint.y / view.bounds.size.height * -2.0) * panSesitivity;
        ((MetalView *)self.view).panX = x + _previousX;
        ((MetalView *)self.view).panY = y + _previousY;
    }
}

@end


































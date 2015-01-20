//
//  ViewController.h
//  ComputeMetal
//
//  Created by Michael Davidson on 1/15/15.
//  Copyright (c) 2015 Michael Davidson. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MetalViewControllerDelegate;

@interface MetalViewController : UIViewController

@property(nonatomic, weak) IBOutlet id<MetalViewControllerDelegate> metalViewControllerDelegate;

//the time interval from the last draw
@property(nonatomic, readonly) NSTimeInterval timeSinceLastDraw;

//what vsync refresh interval to fire at. (Sets CADisplayLink frameinterval property
//set to 1 by default which is the CADisplayLink default setting (60FPS)
//setting to 2 will cause game loop to trigger everyother vsync (30FPS)
@property(nonatomic) NSUInteger interval;

//used to pause and resume
@property(nonatomic) BOOL paused;

//used to fire off main game loop
- (void)dispatchGameLoop;

//use invalidates the main game loop. when the app is set to terminate

@end

@protocol MetalViewControllerDelegate <NSObject>
@required

//note this method is called from the thread the main game loop is run
- (void)update:(MetalViewController *)controller;

//called whenever the main game loop is paused, such as when app is in background
- (void)viewController:(MetalViewController *)controller willPause:(BOOL)pause;

@end


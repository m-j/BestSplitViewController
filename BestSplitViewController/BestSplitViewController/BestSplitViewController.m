//
//  BestSplitViewController.m
//  BestSplitViewController
//
//  Created by Tomasz Janeczko on 27.11.2012.
//  Copyright (c) 2012 Tomasz Janeczko. All rights reserved.
//

#import "BestSplitViewController.h"
#import <QuartzCore/QuartzCore.h>

/** Master View width. */
const int masterWidth = 320;

@interface BestSplitViewController() {
    UIViewController *_masterViewController;
    UIViewController *_detailViewController;
    
    BOOL _isMasterInFullScreenMode;
    BOOL _masterShown;
    
    BOOL _showsMasterInPortrait;
    BOOL _showsMasterInLandscape;
    
    UIPopoverController *_popoverController;
    
    UIBarButtonItem *_popoverBarButtonItem;
}

@end

@implementation BestSplitViewController

@synthesize delegate = _delegate;

#pragma mark - Setup methods
- (void)setup {
    
    // By default, master view is shown
    _masterShown = YES;
    
    _isMasterInFullScreenMode = NO;
    
    // Allow autoresizing of subviews
    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Set default settings
    _showsMasterInPortrait = NO;
    _showsMasterInLandscape = YES;
}

#pragma mark - View lifecycle
- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // Run setup
    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Layout the views before appearing
    [self layoutViewsWithoutAnimation];
}

#pragma mark - View layouting
- (void)layoutViews {
    // By default, layout using status bar orientation and animation
    [self layoutViewsForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation animated:YES];
}

- (void)layoutViewsWithoutAnimation {
    [self layoutViewsForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation animated:NO];
}

- (void)layoutViewsForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation animated:(BOOL)animated {

    // Make sure that master view controller and detail view controller are present
    if (!_masterViewController || !_detailViewController) {
        return;
    }
    
    // Set appropriate autoresizing masks to master and detail view
    if (!_isMasterInFullScreenMode) {
        _masterViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    } else {
        _masterViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    _detailViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    CGRect viewBounds = self.view.bounds;
    
    // Check if should display master in this interface orientation
    if ((_showsMasterInPortrait && UIInterfaceOrientationIsPortrait(interfaceOrientation)) || (_showsMasterInLandscape && UIInterfaceOrientationIsLandscape(interfaceOrientation))) {
            
        // Hide the popover view controller if the button is present
        if (_popoverBarButtonItem || _popoverController.isPopoverVisible) {
            
            // Notify the delegate, dismiss and tidy up
            [self.delegate bestSplitViewController:self willShowViewController:_masterViewController invalidatingBarButtonItem:_popoverBarButtonItem];
            
            [self dismissPopover];
            _popoverBarButtonItem = nil;
        }
        
        // Should show the master - add it to the view hierarchy
        if (!_isMasterInFullScreenMode) {
            // Normal left split frame
            _masterViewController.view.frame = CGRectMake(0, 0, masterWidth, viewBounds.size.height);
        } else {
            // Full screen frame
            _masterViewController.view.frame = CGRectMake(0, 0, viewBounds.size.width, viewBounds.size.height);
        }
        
        // Add the master view to the split view if not set
        if (_masterViewController.view.superview != self.view) {
            [self.view insertSubview:_masterViewController.view aboveSubview:_detailViewController.view];
            _masterShown = YES;
        }
        
        // Set the detail view accordingly in the remaining space
        int detailWidth = viewBounds.size.width - masterWidth - 1;
        _detailViewController.view.frame = CGRectMake(masterWidth + 1, 0, detailWidth, viewBounds.size.height);

    } else {
        
        // Master should be hidden if it's present
        if (_masterShown) {
            [self hideMaster:NO];
        }
        
        // Fill the screen with detail view
        _detailViewController.view.frame = viewBounds;
    }
    
    // If the detail view isn't in the view hierarchy - add it.
    if (!_detailViewController.view.superview) {
        [self.view addSubview:_detailViewController.view];
        [self.view sendSubviewToBack:_detailViewController.view];
    }

}

#pragma mark - Rotation events
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

    // Dismiss popover on rotations
    [self dismissPopover];
    
    // Layout views in the new orientation
    [self layoutViewsForInterfaceOrientation:toInterfaceOrientation animated:NO];
}

#pragma mark - Master view interactions

- (void)hideMaster:(BOOL)animated {
    
    // Hide only if it was previously shown
    if (_masterShown) {
    
        _masterShown = NO;
        
        // Calculate the offscreen target frame
        CGRect masterFrame = _masterViewController.view.frame;
        masterFrame.origin = CGPointMake(-masterFrame.size.width, 0);
        
        // Resize the detail view
        CGRect newDetailFrame = self.view.bounds;
        
        // Define operations for animations
        void(^mainBlock)() = ^{
            _masterViewController.view.frame = masterFrame;
            _detailViewController.view.frame = newDetailFrame;
        };
        
        void(^completionBlock)(BOOL) = ^(BOOL finished) {
            [_masterViewController.view removeFromSuperview];
        };
        
        // Run!
        if (animated) {
            [UIView animateWithDuration:0.5 animations:mainBlock completion:completionBlock];
        } else {
            mainBlock();
            completionBlock(YES);
        }
    }
    
    // Master was hidden, make sure that the delegate has received the suitable bar button item.
    if (!_popoverBarButtonItem) {
        _popoverBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Master" style:UIBarButtonItemStyleBordered target:self action:@selector(showPopover:)];
        _popoverBarButtonItem.title = @"Master";
        
        [self.delegate bestSplitViewController:self willHideViewController:_masterViewController withBarButtonItem:_popoverBarButtonItem forPopoverController:nil];
    }
}

- (void)showMaster:(BOOL)animated {

    // Show only if it was hidden
    if (!_masterShown) {
        
        _masterShown = YES;
        
        CGRect viewBounds, offscreenFrame, finalFrame;
        viewBounds = self.view.bounds;
        
        // Calculate the starting, offscreen frame
        if (!_isMasterInFullScreenMode) {
            // Left split
            offscreenFrame = CGRectMake(-masterWidth, 0, masterWidth, viewBounds.size.height);
        } else {
            // Full screen
            offscreenFrame = CGRectMake(-viewBounds.size.width, 0, viewBounds.size.width, viewBounds.size.height);
        }
        
        // Calculate the final frame
        finalFrame = offscreenFrame;
        finalFrame.origin = CGPointMake(0.0, 0.0);
        
        _masterViewController.view.frame = offscreenFrame;
        [self.view insertSubview:_masterViewController.view aboveSubview:_detailViewController.view];
        
        // Define operations for animations
        void(^mainBlock)() = ^{
            _masterViewController.view.frame = finalFrame;
        };
        
        void(^completionBlock)(BOOL finished) = ^(BOOL finished) {
            [self layoutViews];
            
        };
        
        // Run!
        if (animated) {
            [UIView animateWithDuration:0.5 animations:mainBlock completion:completionBlock];
        } else {
            mainBlock();
            completionBlock(YES);
        }
    }
}

#pragma mark - Master and Detail VC accessors
- (UIViewController *)masterViewController {
    return _masterViewController;
}

- (void)setMasterViewController:(UIViewController *)masterViewController {
    
    // Remove old view controller
    UIViewController *oldViewController = _masterViewController;
    [oldViewController willMoveToParentViewController:nil];
    [oldViewController.view removeFromSuperview];
    [oldViewController removeFromParentViewController];
    
    // Add new one
    _masterViewController = masterViewController;
    
    [masterViewController willMoveToParentViewController:self];
    [self addChildViewController:masterViewController];
    [masterViewController didMoveToParentViewController:self];
    
    masterViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    
    
    // Layout
    if (self.isViewLoaded) {
        [self layoutViewsWithoutAnimation];
    }
}

- (UIViewController *)detailViewController {
    return _detailViewController;
}

- (void)setDetailViewController:(UIViewController *)detailViewController {
    // Remove old view controller
    UIViewController *oldViewController = _detailViewController;
    [oldViewController willMoveToParentViewController:nil];
    [oldViewController.view removeFromSuperview];
    [oldViewController removeFromParentViewController];
    
    // Add new one
    _detailViewController = detailViewController;
    
    [detailViewController willMoveToParentViewController:self];
    [self addChildViewController:detailViewController];
    [detailViewController didMoveToParentViewController:self];
    
    detailViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    // Layout
    if (self.isViewLoaded) {
        [self layoutViewsWithoutAnimation];
    }
}

- (void)setDisplayMasterViewInFullScreenMode:(BOOL)isFullScreen {
    _isMasterInFullScreenMode = isFullScreen;
    
    [self layoutViews];
}

- (BOOL)isDisplayingMasterViewInFullScreenMode {
    return _isMasterInFullScreenMode;
}

- (void)setDefaultMasterVisibility {
    _showsMasterInLandscape = YES;
    _showsMasterInPortrait = NO;
    
    [self layoutViews];
}

- (void)toggleMasterView {
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if (_masterShown) {
        [self hideMaster:YES];
        
        if (UIInterfaceOrientationIsPortrait(currentOrientation)) {
            _showsMasterInPortrait = NO;
        } else {
            _showsMasterInLandscape = NO;
        }
    } else {
        [self showMaster:YES];
        
        if (UIInterfaceOrientationIsPortrait(currentOrientation)) {
            _showsMasterInPortrait = YES;
        } else {
            _showsMasterInLandscape = YES;
        }
    }
}

- (BOOL)isShowingTheMasterViewInLeftSplit {
    return _masterShown;
}

#pragma mark - Popover handling
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    
}

- (void)showPopover:(UIBarButtonItem *)sender {
    if (!_masterViewController.view.superview || !_popoverController.isPopoverVisible) {
        
        [_masterViewController willMoveToParentViewController:nil];
        [_masterViewController removeFromParentViewController];
        
        UIPopoverController *popoverController = [[UIPopoverController alloc] initWithContentViewController:_masterViewController];
        
        float availableHeight = self.view.bounds.size.height;
        
        popoverController.popoverContentSize = CGSizeMake(320, availableHeight);
        popoverController.delegate = self;
        
        [popoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown animated:YES];
        
        _popoverController = popoverController;
        
    }
}

- (void)dismissPopover {
    if (_popoverController) {
        [_popoverController dismissPopoverAnimated:NO];
        
        [_masterViewController willMoveToParentViewController:self];
        [self addChildViewController:_masterViewController];
        [_masterViewController didMoveToParentViewController:self];
        
        _popoverController = nil;
    }
}

@end

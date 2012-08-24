//
//  ASPanningTableViewCell.m
//  Version 0.1
//  Created by Adrian Schoenig on 15/08/12.
//

#import "ASPanningTableViewCell.h"

#define kASPanningImageAlphaOff 0.10f
#define kASAnimationDuration 0.25f
#define kASDefaultDurationToCancelConfirmation 1.5 // seconds

typedef enum {
  BHPanningStateAborted,
  BHPanningStateActivatedLeft,
  BHPanningStateActivatedRight,
  BHPanningStateRequiresConfirmationForLeft,
  BHPanningStateRequiresConfirmationForRight
} BHPanningState;

@interface ASPanningTableViewCell ()
{
  CGPoint initialTouchPoint;
}

/**
 * Limit to how far the user can move the frontView to the left, i.e., to review the image on the right. By default this is 0 if no image on the right exists or the height of the cell if there is one.
 *
 * @see rightImageInBack
 */
@property (nonatomic, assign) CGFloat maxMoveForRightAction;

/**
 * Limit to how far the user can move the frontView to the right, i.e., to review the image on the left. By default this is 0 if no image on the left exists or the height of the cell if there is one.
 *
 * @see leftImageInBack
 */
@property (nonatomic, assign) CGFloat maxMoveForLeftAction;

@property (nonatomic, weak) UIPanGestureRecognizer *panner;
@property (nonatomic, weak) UITapGestureRecognizer *tapper;
@property (nonatomic, weak) UIImageView *rightImageView;
@property (nonatomic, weak) UIImageView *leftImageView;
@property (nonatomic, assign) CGRect defaultLeftImageViewFrame;
@property (nonatomic, assign) CGRect defaultRightImageViewFrame;
@property (nonatomic, assign) BHPanningState currentState;


- (void)handlePan:(UIPanGestureRecognizer *)panner;
- (void)initialise;
- (void)moveViewsForTouchPoint:(CGPoint)point;
- (void)snapBackAndNotify:(BHPanningState)state;
- (BHPanningState)endPanForTouchPoint:(CGPoint)point;
@end

@implementation ASPanningTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier
          frontView:(UIView *)frontView
           backView:(UIView *)backView
{
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    self.backView  = backView;
    self.frontView = frontView;
    [self initialise];
  }
  return self;
}

- (void)awakeFromNib
{
  [self initialise];
}

- (void)prepareForReuse
{
  [self.rightImageView removeFromSuperview];
  [self.leftImageView removeFromSuperview];

  self.defaultLeftImageViewFrame = CGRectNull;
  self.defaultRightImageViewFrame = CGRectNull;
  self.leftPanActionImage = nil;
  self.rightPanActionImage = nil;
  self.maxMoveForLeftAction = self.maxMoveForRightAction = 0;
}

- (void)setBackView:(UIView *)backView
{
  [_backView removeFromSuperview];
  
  [self.contentView insertSubview:backView belowSubview:self.frontView];
  _backView = backView;
  
  // register for tap (to confirm)
  UITapGestureRecognizer *tapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backViewTapped:)];
  tapper.delegate = self;
  [self addGestureRecognizer:tapper];
  self.tapper = tapper;
}

- (void)setLeftPanActionImage:(UIImage *)leftPanActionImage
{
  // out with the old
  [_leftImageView removeFromSuperview];
  self.leftImageView = nil;
  
  // in with the new
  _leftPanActionImage = leftPanActionImage;
  CGFloat height = self.frame.size.height;
  self.maxMoveForLeftAction = height;
  UIImageView *leftImageView = [[UIImageView alloc] initWithImage:_leftPanActionImage];
  CGRect frame = leftImageView.frame;
  frame.origin = CGPointMake((height - _leftPanActionImage.size.width) / 2, (height - _leftPanActionImage.size.height) / 2);
  leftImageView.frame = frame;
  leftImageView.alpha = kASPanningImageAlphaOff;
  [self.backView addSubview:leftImageView];
  self.leftImageView = leftImageView;
  self.defaultLeftImageViewFrame = frame;
}

- (void)setRightPanActionImage:(UIImage *)rightPanActionImage
{
  if (nil == self.backView) {
    // Add a background view if we don't have one
    UIView *emptyBack = [[UIView alloc] initWithFrame:self.frame];
    emptyBack.backgroundColor = [UIColor clearColor];
    emptyBack.opaque = NO;
    self.backView = emptyBack;
  } else {
    // out with the old
    [_rightImageView removeFromSuperview];
    self.rightImageView = nil;
  }
  
  // in with the new
  _rightPanActionImage = rightPanActionImage;
  CGFloat height = self.frame.size.height;
  self.maxMoveForRightAction = height;
  UIImageView *rightImageView = [[UIImageView alloc] initWithImage:_rightPanActionImage];
  CGRect frame = rightImageView.frame;
  frame.origin = CGPointMake(self.frame.size.width - (height + _rightPanActionImage.size.width) / 2, (height - _rightPanActionImage.size.height) / 2);
  rightImageView.frame = frame;
  rightImageView.alpha = kASPanningImageAlphaOff;
  [self.backView addSubview:rightImageView];
  self.rightImageView = rightImageView;
  self.defaultRightImageViewFrame = frame;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == self.panner) {
    UIView *cell = [gestureRecognizer view];
    CGPoint translation = [self.panner translationInView:[cell superview]];
    
    // Check for horizontal gesture
    return fabsf(translation.x) > fabsf(translation.y);
    
  } else if (gestureRecognizer == self.tapper) {
    // check if it's a tap on the border
    CGFloat x = [self.tapper locationInView:self].x;
    if (BHPanningStateRequiresConfirmationForLeft == self.currentState
        && x <= self.maxMoveForLeftAction) {
      return YES;
    }
    
    if (BHPanningStateRequiresConfirmationForRight == self.currentState
        && x >= self.maxMoveForRightAction) {
      return YES;
    }
  }
  
  return NO;
}

#pragma mark - Private methods

- (void)initialise
{
  // Add the gesture recogniser
  UIPanGestureRecognizer *panner = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
  panner.delegate = self;
  [self.frontView addGestureRecognizer:panner];
  self.panner = panner;
  
  // Defaults
  self.maxMoveForRightAction = self.maxMoveForLeftAction = 0;
  self.mode = ASPanningModeMoveImage;
  self.confirmationTimeOut = kASDefaultDurationToCancelConfirmation;
}

- (void)backViewTapped:(UITapGestureRecognizer *)tapper
{
  CGPoint location = [tapper locationInView:self];
  
  if (CGRectContainsPoint(self.leftImageView.frame, location)) {
    [self snapBackAndNotify:BHPanningStateActivatedLeft];
  } else if (CGRectContainsPoint(self.rightImageView.frame, location)) {
    [self snapBackAndNotify:BHPanningStateActivatedRight];
  }
  
//  if (BHPanningStateRequiresConfirmationForLeft == self.currentState) {
//  } else if (BHPanningStateRequiresConfirmationForRight == self.currentState) {
//  }
}

- (void)handlePan:(UIPanGestureRecognizer *)panner
{
  switch (panner.state) {
    case UIGestureRecognizerStateBegan:
      initialTouchPoint = [panner locationInView:self];
      initialTouchPoint.x -= self.frontView.frame.origin.x;
      break;
      
    case UIGestureRecognizerStateChanged:
      // move the front view around
      [self moveViewsForTouchPoint:[panner locationInView:self]];
      break;
      
    case UIGestureRecognizerStateEnded:
      ;// are we far enough to the side to activate?
      BHPanningState state = [self endPanForTouchPoint:[panner locationInView:self]];
      [self finishForState:state];
      break;
      
    default:
      [self snapBackForAbort];
  }
}

- (void)moveViewsForTouchPoint:(CGPoint)point
{
  CGFloat diff = point.x - initialTouchPoint.x;
  
  if (ASPanningModeStopAtMax == self.mode) {
    // Move the front view and stop at the max
    CGRect frontFrame = self.frontView.frame;
    if (diff > self.maxMoveForLeftAction) {
      diff = self.maxMoveForLeftAction;
    } else if (diff < self.maxMoveForRightAction * -1) {
      diff = self.maxMoveForRightAction * -1;
    }
    frontFrame.origin = CGPointMake(diff, 0);
    self.frontView.frame = frontFrame;

  } else if (ASPanningModeMoveImage == self.mode) {
    // Always move the front if we are allowed to move it in that direction
    if ((diff < 0 && self.maxMoveForRightAction > 0)
        || (diff > 0  && self.maxMoveForLeftAction > 0)) {
      CGRect frontFrame = self.frontView.frame;
      frontFrame.origin = CGPointMake(diff, 0);
      self.frontView.frame = frontFrame;
    }
    
    // Move images once the max is exceeded
    if (diff < self.maxMoveForRightAction * -1) {
      CGRect rightImageFrame = self.defaultRightImageViewFrame;
      rightImageFrame.origin = CGPointMake(rightImageFrame.origin.x + diff + self.maxMoveForRightAction, rightImageFrame.origin.y);
      self.rightImageView.frame = rightImageFrame;
    } else if (diff > self.maxMoveForLeftAction) {
      CGRect leftImageFrame = self.defaultLeftImageViewFrame;
      leftImageFrame.origin = CGPointMake(leftImageFrame.origin.x + diff - self.maxMoveForLeftAction, leftImageFrame.origin.y);
      self.leftImageView.frame = leftImageFrame;
    }
    
  } else {
    ZAssert(false, @"Invalid panning mode.");
  }
  
  // Adjust the alpha value of the image
  if (diff < 0) {
    _rightImageView.alpha = MAX(kASPanningImageAlphaOff, MIN(1.0, diff * -1 / self.maxMoveForRightAction));
  } else {
    _leftImageView.alpha = MAX(kASPanningImageAlphaOff, MIN(1.0, diff / self.maxMoveForLeftAction));
  }
}

- (BHPanningState)endPanForTouchPoint:(CGPoint)point
{
  CGFloat diff = point.x - initialTouchPoint.x;
  
  if (diff < 0 && self.maxMoveForRightAction > 0 && diff * -1 >= self.maxMoveForRightAction) {
    if (self.rightPanActionRequiresConfirmation) {
      return BHPanningStateRequiresConfirmationForRight;
    } else {
      return BHPanningStateActivatedRight;
    }
    
  } else if (diff > 0 && self.maxMoveForLeftAction > 0 && diff >= self.maxMoveForLeftAction) {
    if (self.leftPanActionRequiresConfirmation) {
      return BHPanningStateRequiresConfirmationForLeft;
    } else {
      return BHPanningStateActivatedLeft;
    }
  } else {
    return BHPanningStateAborted;
  }
}

- (void)finishForState:(BHPanningState)state
{
  switch (state) {
    case BHPanningStateActivatedLeft:
    case BHPanningStateActivatedRight:
      [self snapBackAndNotify:state];
      break;

    case BHPanningStateRequiresConfirmationForLeft:
    case BHPanningStateRequiresConfirmationForRight:
      [self snapToConfirmation:state];
      break;

    default:
      [self snapBackForAbort];
  }
}

- (void)snapToConfirmation:(BHPanningState)state
{
  self.currentState = state;

  [UIView animateWithDuration:kASAnimationDuration
                        delay:0
                      options:UIViewAnimationCurveEaseOut
                   animations:
   ^{
     CGRect frame = self.frontView.frame;
     if (BHPanningStateRequiresConfirmationForLeft == state) {
       frame.origin = CGPointMake(self.maxMoveForLeftAction, 0);
       _leftImageView.alpha = 1.0f;
       _leftImageView.frame = _defaultLeftImageViewFrame;
     } else if (BHPanningStateRequiresConfirmationForRight) {
       _rightImageView.alpha = 1.0f;
       _rightImageView.frame = _defaultRightImageViewFrame;
     }
     self.frontView.frame = frame;
   }
                   completion:
   ^(BOOL finished) {
     [self performSelector:@selector(snapBackForAbort) withObject:nil afterDelay:self.confirmationTimeOut];
   }];
}

- (void)snapBackForAbort
{
  [self snapBackAndNotify:BHPanningStateAborted];
}

- (void)snapBackAndNotify:(BHPanningState)state
{
  NSAssert(state != BHPanningStateRequiresConfirmationForLeft && state != BHPanningStateRequiresConfirmationForRight, @"Can't be in a confirmation state here!");

  self.currentState = state;
  
  UITableView *tableView = (UITableView *) self.superview;
  id delegate = tableView.delegate;

  CGRect frame = self.frontView.frame;
  frame.origin = CGPointMake(0, 0);
  
  [UIView animateWithDuration:kASAnimationDuration
                        delay:0
                      options:UIViewAnimationCurveEaseOut
                   animations:
   ^{
     self.frontView.frame = frame;
     _leftImageView.alpha = kASPanningImageAlphaOff;
     _leftImageView.frame = _defaultLeftImageViewFrame;
     _rightImageView.alpha = kASPanningImageAlphaOff;
     _rightImageView.frame = _defaultRightImageViewFrame;
   }
                   completion:
   ^(BOOL finished) {
     if (BHPanningStateActivatedLeft == state) {
       if ([delegate respondsToSelector:@selector(tableView:triggeredLeftPanActionAtIndexPath:)]) {
         NSIndexPath *path = [tableView indexPathForCell:self];
         [delegate tableView:tableView triggeredLeftPanActionAtIndexPath:path];
       }
       
     } else if (BHPanningStateActivatedRight == state) {
       if ([delegate respondsToSelector:@selector(tableView:triggeredRightPanActionAtIndexPath:)]) {
         NSIndexPath *path = [tableView indexPathForCell:self];
         [delegate tableView:tableView triggeredRightPanActionAtIndexPath:path];
       }
     }
   }];
}

@end

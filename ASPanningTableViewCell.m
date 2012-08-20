//
//  ASPanningTableViewCell.m
//  Version 0.1
//  Created by Adrian Schoenig on 15/08/12.
//

#import "ASPanningTableViewCell.h"

#define kASPanningImageAlphaOff 0.10f
#define kASAnimationDuration 0.25f

typedef enum {
  BHPanningStateAborted,
  BHPanningStateActivatedLeft,
  BHPanningStateActivatedRight
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
@property (nonatomic, assign) CGFloat maxMoveToLeft;

/**
 * Limit to how far the user can move the frontView to the right, i.e., to review the image on the left. By default this is 0 if no image on the left exists or the height of the cell if there is one.
 *
 * @see leftImageInBack
 */
@property (nonatomic, assign) CGFloat maxMoveToRight;

@property (nonatomic, weak) UIPanGestureRecognizer *panner;
@property (nonatomic, weak) UIImageView *rightImageView;
@property (nonatomic, weak) UIImageView *leftImageView;
@property (nonatomic, assign) CGRect defaultLeftImageViewFrame;
@property (nonatomic, assign) CGRect defaultRightImageViewFrame;

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
  self.leftImageInBack = nil;
  self.rightImageInBack = nil;
  self.maxMoveToRight = self.maxMoveToLeft = 0;
}

- (void)setBackView:(UIView *)backView
{
  [_backView removeFromSuperview];
  
  [self.contentView insertSubview:backView belowSubview:self.frontView];
  _backView = backView;
}

- (void)setLeftImageInBack:(UIImage *)leftImageInBack
{
  // out with the old
  [_leftImageView removeFromSuperview];
  self.leftImageView = nil;
  
  // in with the new
  _leftImageInBack = leftImageInBack;
  CGFloat height = self.frame.size.height;
  self.maxMoveToRight = height;
  UIImageView *leftImageView = [[UIImageView alloc] initWithImage:_leftImageInBack];
  CGRect frame = leftImageView.frame;
  frame.origin = CGPointMake((height - _leftImageInBack.size.width) / 2, (height - _leftImageInBack.size.height) / 2);
  leftImageView.frame = frame;
  leftImageView.alpha = kASPanningImageAlphaOff;
  [self.backView addSubview:leftImageView];
  self.leftImageView = leftImageView;
  self.defaultLeftImageViewFrame = frame;
}

- (void)setRightImageInBack:(UIImage *)rightImageInBack
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
  _rightImageInBack = rightImageInBack;
  CGFloat height = self.frame.size.height;
  self.maxMoveToLeft = height;
  UIImageView *rightImageView = [[UIImageView alloc] initWithImage:_rightImageInBack];
  CGRect frame = rightImageView.frame;
  frame.origin = CGPointMake(self.frame.size.width - (height + _rightImageInBack.size.width) / 2, (height - _rightImageInBack.size.height) / 2);
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
  self.maxMoveToLeft = self.maxMoveToRight = 0;
  self.mode = ASPanningModeMoveImage;
}

- (void)handlePan:(UIPanGestureRecognizer *)panner
{
  switch (panner.state) {
    case UIGestureRecognizerStateBegan:
      initialTouchPoint = [panner locationInView:self];
      break;
      
    case UIGestureRecognizerStateChanged:
      // move the front view around
      [self moveViewsForTouchPoint:[panner locationInView:self]];
      break;
      
    case UIGestureRecognizerStateEnded:
      ;// are we far enough to the side to activate?
      BHPanningState state = [self endPanForTouchPoint:[panner locationInView:self]];
      [self snapBackAndNotify:state];
      break;
      
    default:
      [self snapBackAndNotify:BHPanningStateAborted];
  }
}

- (void)moveViewsForTouchPoint:(CGPoint)point
{
  CGFloat diff = point.x - initialTouchPoint.x;
  
  if (ASPanningModeStopAtMax == self.mode) {
    // Move the front view and stop at the max
    CGRect frontFrame = self.frontView.frame;
    if (diff > self.maxMoveToRight) {
      diff = self.maxMoveToRight;
    } else if (diff < self.maxMoveToLeft * -1) {
      diff = self.maxMoveToLeft * -1;
    }
    frontFrame.origin = CGPointMake(diff, 0);
    self.frontView.frame = frontFrame;

  } else if (ASPanningModeMoveImage == self.mode) {
    // Always move the front if we are allowed to move it in that direction
    if ((diff < 0 && self.maxMoveToLeft > 0)
        || (diff > 0  && self.maxMoveToRight > 0)) {
      CGRect frontFrame = self.frontView.frame;
      frontFrame.origin = CGPointMake(diff, 0);
      self.frontView.frame = frontFrame;
    }
    
    // Move images once the max is exceeded
    if (diff < self.maxMoveToLeft * -1) {
      CGRect rightImageFrame = self.defaultRightImageViewFrame;
      rightImageFrame.origin = CGPointMake(rightImageFrame.origin.x + diff + self.maxMoveToLeft, rightImageFrame.origin.y);
      self.rightImageView.frame = rightImageFrame;
    } else if (diff > self.maxMoveToRight) {
      CGRect leftImageFrame = self.defaultLeftImageViewFrame;
      leftImageFrame.origin = CGPointMake(leftImageFrame.origin.x + diff - self.maxMoveToRight, leftImageFrame.origin.y);
      self.leftImageView.frame = leftImageFrame;
    }
    
  } else {
    ZAssert(false, @"Invalid panning mode.");
  }
  
  // Adjust the alpha value of the image
  if (diff < 0) {
    _rightImageView.alpha = MAX(kASPanningImageAlphaOff, MIN(1.0, diff * -1 / self.maxMoveToLeft));
  } else {
    _leftImageView.alpha = MAX(kASPanningImageAlphaOff, MIN(1.0, diff / self.maxMoveToRight));
  }
}

- (BHPanningState)endPanForTouchPoint:(CGPoint)point
{
  CGFloat diff = point.x - initialTouchPoint.x;
  
  if (diff < 0 && self.maxMoveToLeft > 0 && diff * -1 >= self.maxMoveToLeft) {
    return BHPanningStateActivatedRight;
  } else if (diff > 0 && self.maxMoveToRight > 0 && diff >= self.maxMoveToRight) {
    return BHPanningStateActivatedLeft;
  } else {
    return BHPanningStateAborted;
  }
}

- (void)snapBackAndNotify:(BHPanningState)state
{
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
       if ([delegate respondsToSelector:@selector(tableView:didActiveLeftAtIndexPath:)]) {
         NSIndexPath *path = [tableView indexPathForCell:self];
         [delegate tableView:tableView didActiveLeftAtIndexPath:path];
       }
       
     } else if (BHPanningStateActivatedRight == state) {
       if ([delegate respondsToSelector:@selector(tableView:didActiveRightAtIndexPath:)]) {
         NSIndexPath *path = [tableView indexPathForCell:self];
         [delegate tableView:tableView didActiveRightAtIndexPath:path];
       }
     }
   }];
}

@end

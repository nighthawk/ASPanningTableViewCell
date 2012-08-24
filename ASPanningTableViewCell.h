//
//  ASPanningTableViewCell.h
//  Version 0.1
//  Created by Adrian Schoenig on 15/08/12.
//

// Copyright (c) 2012 Adrian Schoenig

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
  ASPanningModeStopAtMax, // Stop moving the frontView if max is reached
  ASPanningModeMoveImage  // Keep moving frontView and move images as well if max is reached
} ASPanningMode;

/**
 * A UITableViewCell subclass which consists of a front (i.e., the part that's usually visibile) and a back. The user can drag the front to the side and reveal the back. If the cell is moved far enough to the side, the cell's UITableView's delegate will get notified.
 *
 * To make the UITableViewCell draggable, you need to assign the 'frontView' property and supply an image for either the left or right in the back and implement at least one of the protocol methods.
 */
@interface ASPanningTableViewCell : UITableViewCell <UIGestureRecognizerDelegate>

/**
 * The view which will receive panning input and which will get moved accordingly.
 */
@property (nonatomic, strong) IBOutlet UIView *frontView;

/**
 * The view which will become visible behind the front when the user is panning.
 */
@property (nonatomic, strong) IBOutlet UIView *backView;

/**
 * Image that gets added to the left in the backView.
 */
@property (nonatomic, strong) IBOutlet UIImage *leftPanActionImage;

/**
 * Image that gets added to the right in the backView.
 */
@property (nonatomic, strong) IBOutlet UIImage *rightPanActionImage;

/**
 * If the left action needs to activated manually rather than just through
 * the panning.
 * @default NO
 */
@property (nonatomic, assign) BOOL leftPanActionRequiresConfirmation;

/**
 * If the right action needs to activated manually rather than just through
 * the panning.
 * @default NO
 */
@property (nonatomic, assign) BOOL rightPanActionRequiresConfirmation;

/**
 * The time out after which confirmations are aborted.
 * @default 1.5 (seconds)
 */
@property (nonatomic, assign) NSTimeInterval confirmationTimeOut;

/**
 * Panning mode. Defaults to 'ASPanningModeMoveImage'.
 * @see ASPanningMode
 */
@property (nonatomic, assign) ASPanningMode mode;

/**
 * Custom initialiser.
 *
 * @param style As in UITableViewCell
 * @param reuseIdentifier As in UITAbleViewCell
 * @param frontView The front view which will be draggable (or 'nil' if you don't want dragging)
 * @param backView An optional custom view for the back
 * @return The initialized instance of the SGPanningTableViewCell
 */
- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier
          frontView:(UIView *)frontView
           backView:(UIView *)backView;

@end

@protocol ASPanningTableViewDelegate <UITableViewDelegate>

@optional
/**
 * Called when the user moves the frontView far enough to the right to reveal the image on the left and releases the view properly.
 *
 * @param tableView The UITableView that the cell is part of
 * @param indexPath The index path of the cell in that table view
 */
- (void)tableView:(UITableView *)tableView triggeredLeftPanActionAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Called when the user moves the frontView far enough to the left to reveal the image on the right and releases the view properly.
 *
 * @param tableView The UITableView that the cell is part of
 * @param indexPath The index path of the cell in that table view
 */
- (void)tableView:(UITableView *)tableView triggeredRightPanActionAtIndexPath:(NSIndexPath *)indexPath;

@end



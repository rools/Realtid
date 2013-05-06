//
//  StopCell.h
//  Realtid
//
//  Created by Robert Olsson on 2011-06-16.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface StopCell : UITableViewCell {
    IBOutlet UILabel *stopLabel;
    IBOutlet UILabel *distanceLabel;
}

@property (nonatomic, retain) IBOutlet UILabel *stopLabel;
@property (nonatomic, retain) IBOutlet UILabel *distanceLabel;

@end

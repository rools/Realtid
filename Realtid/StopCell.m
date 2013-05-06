//
//  StopCell.m
//  Realtid
//
//  Created by Robert Olsson on 2011-06-16.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "StopCell.h"


@implementation StopCell

@synthesize stopLabel;
@synthesize distanceLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    //[super setSelected:selected animated:animated];

    // Configure the view for the selected state
    //self.stopLabel.textColor = [UIColor grayColor];
}

- (void)dealloc
{
    //[super dealloc];
}

@end

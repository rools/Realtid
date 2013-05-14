//
//  StopCell.h
//  Realtid
//
//  Created by Robert Olsson on 2011-06-16.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Stop.h"

@interface StopCell : UITableViewCell {
    IBOutlet UILabel *stopLabel;
    IBOutlet UILabel *distanceLabel;
	NSMutableArray *addedViews;
}

@property (nonatomic, retain) IBOutlet UILabel *stopLabel;
@property (nonatomic, retain) IBOutlet UILabel *distanceLabel;

- (void)loadStop:(Stop *)stop isDeparturesLoading:(BOOL)isDeparturesLoading;
- (void)loadDepartures:(NSDictionary *)departures;
+ (CGFloat)cellHeight:(NSDictionary *)departures;
+ (StopCell *)cell;

@end

//
//  StopCell.m
//  Realtid
//
//  Created by Robert Olsson on 2011-06-16.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "StopCell.h"
#import "Stop.h"
#import "Util.h"
#import "Departure.h"

@implementation StopCell

@synthesize stopLabel;
@synthesize distanceLabel;

static const CGFloat DEPARTURE_HEIGHT = 21;
static const CGFloat TRANSPORT_SPACING = 20;
static const CGFloat GROUP_SPACING = 20;
static const CGFloat DEPARTURE_SPACING = 2;

static const CGFloat DEPARTURE_NAME_X = 44;
static const CGFloat DEPARTURE_NAME_WIDTH = 178;
static const CGFloat DEPARTURE_TIME_X = 247;
static const CGFloat DEPARTURE_TIME_WIDTH = 56;

static const CGFloat GROUP_ICON_X = 8;
static const CGFloat GROUP_ICON_SIZE = 32;

static const CGFloat MESSAGE_X = 20;
static const CGFloat MESSAGE_WIDTH = 202;
static const CGFloat MESSAGE_HEIGHT = 30;

static const CGFloat MAX_DEPARTURES_PER_GROUP = 4;

static NSDateFormatter *timeDateFormatter;

+ (void)initialize {
	timeDateFormatter = [[NSDateFormatter alloc] init];
	[timeDateFormatter setDateFormat:@"HH:mm"];
}

-(id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder: aDecoder];
	if (self) {
		addedViews = [[NSMutableArray alloc] init];
	}
	return self;
}

// Maybe move these functions to a util class?

+ (NSString *)formatDistance:(NSInteger)meters {
	// Round to two significatnt figures
	double n = pow(10, floor(log10(meters)) - 1);
	meters = round(meters / n) * n;
	
	if (meters < 1e3)
		return [NSString stringWithFormat:@"%i m", meters];
	if (meters > 100e3)
		return @"100+ km";
	
	double kilometers = meters / 1000.0;
	
	// Always show two significant digits
	if (kilometers < 10.0)
		return [NSString stringWithFormat:@"%.1f km", kilometers];
	
	return [NSString stringWithFormat:@"%.2g km", kilometers];
}

+ (NSString *)formatTime:(NSDate *)date {
	NSTimeInterval interval = [date timeIntervalSinceDate:[Util currentMinute]];
	
	// Show minutes left if the date is within an hour
	if (interval < 3600.0) {
		NSInteger minutes = round(interval / 60);
		if (minutes == 0)
			return @"NU";
		return [NSString stringWithFormat:@"%i min", minutes];
	}
	
	return [timeDateFormatter stringFromDate:date];
}

// Calculate the height of a cell containing the specified departures
+ (CGFloat)cellHeight:(NSDictionary *)departures {
	NSInteger height = 0;

	if ([departures count] == 0)
		return MESSAGE_HEIGHT + 10;

	for (NSString *transportTypeName in departures) {
		NSDictionary *groups = [departures objectForKey:transportTypeName];

		for (NSString *groupName in groups) {
			NSArray *group = [groups objectForKey:groupName];
			
			height += DEPARTURE_HEIGHT + DEPARTURE_SPACING;
			height += MIN([group count], MAX_DEPARTURES_PER_GROUP) * (DEPARTURE_HEIGHT + DEPARTURE_SPACING);
			height -= DEPARTURE_SPACING;
			height += GROUP_SPACING;
		}
		
		height -= GROUP_SPACING;
		
		height += TRANSPORT_SPACING;
	}
	
	return height;
}

- (void)addView:(UIView *)view {
	[addedViews addObject:view];
	[self addSubview:view];
}

- (void)clearViews {
	for (UIView *view in addedViews)
		[view removeFromSuperview];
	[addedViews removeAllObjects];
}

- (void)loadStop:(Stop *)stop isDeparturesLoading:(BOOL)isDeparturesLoading {
	// Remove dynamically added sub views
	[self clearViews];

	stopLabel.text = stop.name;
    distanceLabel.text = [StopCell formatDistance:stop.distance];

	UIColor *color;
	
	// TODO: Tidy up this coloring code... 
	UIColor *near = [UIColor colorWithRed:0.0 green:(120.0/256) blue:(23.0 / 256.0) alpha:1.0];
	UIColor *medium = [UIColor colorWithRed:0.8*(254.0 / 256.0) green:0.8*(220.0/256) blue:0.8*(8.0 / 256.0) alpha:1.0];
	UIColor *far = [UIColor colorWithRed:(154.0 / 256.0) green:(1.0/256) blue:(22.0 / 256.0) alpha:1.0];
	
	const float nearThreshold = 200.0;
	const float mediumThreshold = 800.0;
	const float farThreshold = 2000.0;
	
	if (stop.distance < nearThreshold) {
		color = near;
	} else if (stop.distance < mediumThreshold) {
		float c = (stop.distance - nearThreshold) / (mediumThreshold - nearThreshold);
		float ci = 1.0 - c;
		CGFloat r1, g1, b1, r2, g2, b2, a;
		[near getRed:&r1 green:&g1 blue:&b1 alpha: &a];
		[medium getRed:&r2 green:&g2 blue:&b2 alpha: &a];
		color = [UIColor colorWithRed:(r1 * ci + r2 * c) green:(g1 * ci + g2 * c) blue:(b1 * ci + b2 * c) alpha:a];
	} else if (stop.distance < farThreshold) {
		float c = (stop.distance - mediumThreshold) / (farThreshold - mediumThreshold);
		float ci = 1.0 - c;
		CGFloat r1, g1, b1, r2, g2, b2, a;
		[medium getRed:&r1 green:&g1 blue:&b1 alpha: &a];
		[far getRed:&r2 green:&g2 blue:&b2 alpha: &a];
		color = [UIColor colorWithRed:(r1 * ci + r2 * c) green:(g1 * ci + g2 * c) blue:(b1 * ci + b2 * c) alpha:a];
	} else {
		color = far;
	}
	
	if (isDeparturesLoading) {
		CGFloat r, g, b, a;
		[color getRed:&r green:&g blue:&b alpha: &a];
		color = [UIColor colorWithRed:(r * 0.5) green:(g * 0.5) blue:(b * 0.5) alpha:a];
	}

	self.contentView.backgroundColor = color;
}

- (void)loadDepartures:(NSDictionary *)departures {
	CGFloat y = 69;

	if ([departures count] > 0) {
		for (NSString *transportTypeName in departures) {
			NSDictionary *groups = [departures objectForKey:transportTypeName];
			
			UIImage *groupImage;
			
			if ([transportTypeName isEqualToString:@"MetroList"])
				groupImage = [UIImage imageNamed:@"subway.png"];
			else if ([transportTypeName isEqualToString:@"BusList"])
				groupImage = [UIImage imageNamed:@"bus.png"];
			else if ([transportTypeName isEqualToString:@"TramList"])
				groupImage = [UIImage imageNamed:@"tram.png"];
			else if ([transportTypeName isEqualToString:@"TrainList"])
				groupImage = [UIImage imageNamed:@"train.png"];
			else
				groupImage = nil;
			
			for (NSString *groupName in groups) {
				NSArray *group = [groups objectForKey:groupName];
				
				UILabel *destinationLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEPARTURE_NAME_X, y, DEPARTURE_NAME_WIDTH, DEPARTURE_HEIGHT)];
				destinationLabel.backgroundColor = [UIColor clearColor];
				destinationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
				destinationLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
				[destinationLabel setText:groupName];
				[self addView:destinationLabel];
				y += DEPARTURE_HEIGHT + DEPARTURE_SPACING;
				
				// Group transport icon
				CGFloat iconY = y + 0.5 * (MIN([group count], MAX_DEPARTURES_PER_GROUP) * (DEPARTURE_HEIGHT + DEPARTURE_SPACING) - DEPARTURE_SPACING) - 0.5 * GROUP_ICON_SIZE;
				UIImageView *groupIcon = [[UIImageView alloc] initWithFrame:CGRectMake(GROUP_ICON_X, iconY, 32, 32)];
				groupIcon.image = groupImage;
				groupIcon.contentMode = UIViewContentModeCenter;
				[self addView:groupIcon];
				
				int departureCount = 0;
				
				for (Departure *departure in group) {
					if (departureCount >= MAX_DEPARTURES_PER_GROUP)
						break;
					
					// Destination label
					NSString *destination = [NSString stringWithFormat:@"%@ %@", departure.line, departure.destination];
					UILabel *destinationLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEPARTURE_NAME_X, y, DEPARTURE_NAME_WIDTH, DEPARTURE_HEIGHT)];
					destinationLabel.backgroundColor = [UIColor clearColor];
					destinationLabel.textColor = [UIColor whiteColor];
					destinationLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
					[destinationLabel setText:destination];
					[self addView:destinationLabel];
					
					// Time label
					UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEPARTURE_TIME_X, y, DEPARTURE_TIME_WIDTH, DEPARTURE_HEIGHT)];
					timeLabel.backgroundColor = [UIColor clearColor];
					timeLabel.textColor = [UIColor whiteColor];
					timeLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
					timeLabel.textAlignment = NSTextAlignmentRight;
					[timeLabel setText:[StopCell formatTime:departure.time]];
					[self addView:timeLabel];
					
					y += DEPARTURE_HEIGHT + DEPARTURE_SPACING;
					
					departureCount++;
				}
				
				y -= DEPARTURE_SPACING;
				
				y += GROUP_SPACING;
			}
			y -= GROUP_SPACING;
			
			y += TRANSPORT_SPACING;
		}
	} else {
		// Currently no available departures for this stop
		UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(MESSAGE_X, y, MESSAGE_WIDTH, MESSAGE_HEIGHT)];
		messageLabel.backgroundColor = [UIColor clearColor];
		messageLabel.textColor = [UIColor whiteColor];
		messageLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
		messageLabel.textAlignment = NSTextAlignmentCenter;
		[messageLabel setText:@"Inga avgångar"];
		[self addView:messageLabel];
	}
}

+ (StopCell *)cell {
	return [[[NSBundle mainBundle] loadNibNamed:@"StopCell" owner:self options:nil] objectAtIndex:0];
}

@end

//
//  Util.m
//  Realtid
//
//  Created by Robert Olsson on 5/12/13.
//  Copyright (c) 2013 Robert Olsson. All rights reserved.
//

#import "Util.h"

@implementation Util

// Get the current date, rounded to previous minute
+ (NSDate *)currentMinute {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	
	NSDateComponents *dateComponents = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:[NSDate date]];
	
	[dateComponents setSecond:0];
	
	return [calendar dateFromComponents:dateComponents];
}

@end

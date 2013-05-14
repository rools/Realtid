//
//  StopDatabase.m
//  Realtid
//
//  Created by Robert Olsson on 2011-05-08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XPathQuery.h"
#import "StopDatabase.h"
#import "Stop.h"
#import "Departure.h"


@implementation StopDatabase

static StopDatabase *database_;

+ (StopDatabase*)database {
    if (database_ == nil) {
        database_ = [[StopDatabase alloc] init];
    }
    return database_;
}

// Convert an HH:mm formatted time string to a date 
- (NSDate *)dateFromTimeString:(NSString *)timeString currentDate:(NSDate *)currentDate {
	NSDate *time = [timeDateFormatter dateFromString:timeString];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *dateComponents = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:currentDate];
	NSDateComponents *timeComponents = [calendar components:NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:time];

	dateComponents.hour = [timeComponents hour];
	dateComponents.minute = [timeComponents minute];
	dateComponents.second = 0;

	NSDate *date = [calendar dateFromComponents:dateComponents];

	// If the date is more than 12 hours in the past, assume the time stamp referes to a time tomorrow instead
	if ([date timeIntervalSinceDate:currentDate] < -12 * 3600) {
		NSDateComponents *oneDay = [[NSDateComponents alloc] init];
		oneDay.day = 1;
		date = [calendar dateByAddingComponents:oneDay toDate:date options:0];
	}
	
	return date;
}

// Convert a time string (e.g. NU, XX min, HH:mm) to a date
- (NSDate *)timeStringToDate:(NSString *)time currentDate:(NSDate *)currentDate {
	if ([time isEqualToString:@"NU"])
		return currentDate;

	if ([departureTimeRegex firstMatchInString:time options:0 range:NSMakeRange(0, [time length])])
		return [self dateFromTimeString:time currentDate:currentDate];
	
	NSTextCheckingResult *match = [departureMinutesRegex firstMatchInString:time options:0 range:NSMakeRange(0, [time length])];

	if (match) {
		NSInteger minutes = [[time substringWithRange:[match rangeAtIndex:1]] integerValue];
		return [currentDate dateByAddingTimeInterval:(60 * minutes)];
	}

	return nil;
}

- (id)init {
    if ((self = [super init])) {
        NSString *sqLiteDb = [[NSBundle mainBundle] pathForResource:@"realtime" ofType:@"sqlite"];
        if (sqlite3_open([sqLiteDb UTF8String], &database_) != SQLITE_OK)
            NSLog(@"Failed to open stops database!");

		departureTimeRegex = [NSRegularExpression regularExpressionWithPattern:@"[0-9]{2}:[0-9]{2}" options:0 error:nil];
		departureMinutesRegex = [NSRegularExpression regularExpressionWithPattern:@"([0-9]+) min" options:0 error:nil];
		currentTimeRegex = [NSRegularExpression regularExpressionWithPattern:@"kl ([0-9]{2}:[0-9]{2})" options:0 error:nil];
	
		timeDateFormatter = [[NSDateFormatter alloc] init];
		[timeDateFormatter setDateFormat:@"HH:mm"];
    }
    return self;
}

- (void)dealloc {
    sqlite3_close(database_);
    //[super dealloc];
}

- (NSArray *)stopsWithLocation:(CLLocation *)location andName:(NSString *)name {
    NSMutableArray *stops = [[NSMutableArray alloc] init];

	NSString *nameFilter = @"";
	if (name.length > 0)
		nameFilter = @"WHERE name MATCH ?";

	NSString *query = [NSString stringWithFormat:@"SELECT id, name, latitude, longitude, ((longitude - ?) * (longitude - ?) * 0.259 + (latitude - ?) * (latitude - ?)) as d FROM stops_fts %@ ORDER BY d LIMIT 40", nameFilter];
	
    sqlite3_stmt *statement;
	if (sqlite3_prepare(database_, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
		sqlite3_bind_double(statement, 1, location.coordinate.longitude);
		sqlite3_bind_double(statement, 2, location.coordinate.longitude);
		sqlite3_bind_double(statement, 3, location.coordinate.latitude);
		sqlite3_bind_double(statement, 4, location.coordinate.latitude);

		if (name.length > 0)
			sqlite3_bind_text(statement, 5, [[NSString stringWithFormat:@"%@*", name] UTF8String], -1, SQLITE_TRANSIENT);

		while (sqlite3_step(statement) == SQLITE_ROW) {
			Stop *stop = [Stop alloc];
			stop.identifier = sqlite3_column_int(statement, 0);
			stop.name = [[NSString alloc] initWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
			stop.distance = round([location distanceFromLocation:[[CLLocation alloc] initWithLatitude:sqlite3_column_double(statement, 2) longitude:sqlite3_column_double(statement, 3)]]);

            [stops addObject:stop];
        }
        sqlite3_finalize(statement);
	}

    return stops;
}

- (NSDictionary *)depaturesAtStop:(NSInteger)stop error:(NSError **)error {
	NSMutableDictionary *trafficTypes = [[NSMutableDictionary alloc] init];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://mobil.sl.se/sv/Avgangar/Sok/?siteId=%i", stop]];
	NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];

	if (*error)
		return nil;

	NSArray *trafficTypesDom = PerformHTMLXPathQuery(data, @"//ul[@class='traffic-types toggleable']/li/ul");

	// If the DOM array is nil, a parse error occured
	if (!trafficTypes) {
		*error = [NSError errorWithDomain:@"net.rools.realtid" code:NSURLErrorCannotParseResponse userInfo:nil];
		return nil;
	}
	
	// TODO: check for MainPlaceHolder_ctl00_NoInformationLabel, to differentiate between 'no departures' and 'parse error'

	// If we don't have any traffic types, the stop doesn't have any current departures
	if ([trafficTypesDom count] == 0)
		return  trafficTypes;

	// Extract current time
	NSDate *currentDate;
	{
		NSArray *times = PerformHTMLXPathQuery(data, @"//ul[@class='traffic-types toggleable']/li/div/small");

		assert([times count] > 0);
		
		NSString *time = [[times objectAtIndex:0] objectForKey:@"nodeContent"];
		
		assert(time != nil);

		NSTextCheckingResult *match = [currentTimeRegex firstMatchInString:time options:0 range:NSMakeRange(0, [time length])];
		
		assert(match != nil);
		
		currentDate = [self dateFromTimeString:[time substringWithRange:[match rangeAtIndex:1]] currentDate:[NSDate date]];
	}

	for (id typeDom in trafficTypesDom) {
		// Get transport type (metro, buses etc.)
		NSString *typeName;
		for (NSDictionary *attribute in [typeDom objectForKey:@"nodeAttributeArray"]) {
			if ([[attribute objectForKey:@"attributeName"] isEqualToString:@"id"])
				typeName = [attribute objectForKey:@"nodeContent"];
		}
		assert(typeName != nil);

		// Get departure groups (different metro lines, different bus stop locations etc.)
		NSMutableDictionary *groups = [[NSMutableDictionary alloc] init];
		NSArray *groupsDom = [typeDom objectForKey:@"nodeChildArray"];

		for (NSDictionary *groupDom in groupsDom) {
			NSString *groupName = [[[groupDom objectForKey:@"nodeChildArray"] objectAtIndex:0] objectForKey:@"nodeContent"];
			
			// Remove unnessesary parts of group name
			groupName = [groupName stringByReplacingOccurrencesOfString:@", mot:" withString:@""];
			
			// Train groups have weird titles
			if ([typeName isEqualToString:@"TrainList"] && [groupName isEqualToString:@"Mot:"])
				groupName = @"Pendeltåg";

			// Create new group if it doesn't already exist in dictionary
			NSMutableArray *departures = [groups objectForKey:groupName];
			if (!departures)
				departures = [[NSMutableArray alloc] init];

			for (NSDictionary *d in [[[groupDom objectForKey:@"nodeChildArray"] objectAtIndex:1] objectForKey:@"nodeChildArray"]) {
				// This node can not contain a departure
				if ([[d objectForKey:@"nodeChildArray"] count] < 3)
					continue;

				Departure *departure = [Departure alloc];

				departure.line = [[[d objectForKey:@"nodeChildArray"] objectAtIndex:0] objectForKey:@"nodeContent"];
				departure.destination = [[[d objectForKey:@"nodeChildArray"] objectAtIndex:1] objectForKey:@"nodeContent"];
				departure.time = [self timeStringToDate:[[[d objectForKey:@"nodeChildArray"] objectAtIndex:2] objectForKey:@"nodeContent"] currentDate:currentDate];

				[departures addObject:departure];
			}
			
			// Only save group if it is not empty
			if ([departures count] > 0)
				[groups setValue:departures forKey:groupName];
		}
		
		[trafficTypes setValue:groups forKey:typeName];
	}
	
	// Sort departures
	NSMutableDictionary *sortedTrafficTypes = [[NSMutableDictionary alloc] init];
	for (NSString *transportTypeName in trafficTypes) {
		NSMutableDictionary *groups = [trafficTypes objectForKey:transportTypeName];
		NSMutableDictionary *sortedGroups = [[NSMutableDictionary alloc] init];
		for (NSString *groupName in groups) {			
			NSArray *group = [groups objectForKey:groupName];
			group = [group sortedArrayUsingComparator:^NSComparisonResult(Departure *d1, Departure *d2) {
				return [d1.time compare:d2.time];
			}];
			
			[sortedGroups setValue:group forKey:groupName];
		}

		[sortedTrafficTypes setValue:sortedGroups forKey:transportTypeName];
	}

	return sortedTrafficTypes;
}

@end

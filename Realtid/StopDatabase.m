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


@implementation StopDatabase

static StopDatabase *database_;

+ (StopDatabase*)database {
    if (database_ == nil) {
        database_ = [[StopDatabase alloc] init];
    }
    return database_;
}

- (NSDate *)dateFromTimeString:(NSString *)timeString {
	NSDate *time = [timeDateFormatter dateFromString:timeString];
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *dateComponents = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
	NSDateComponents *timeComponents = [calendar components:NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:time];
	[dateComponents setHour:[timeComponents hour]];
	[dateComponents setMinute:[timeComponents minute]];
	[dateComponents setSecond:0];
	return [calendar dateFromComponents:dateComponents];
}

- (NSDate *)timeStringToDate:(NSString *)time currentDate:(NSDate *)currentDate {
	if ([time isEqualToString:@"NU"])
		return currentDate;

	if ([departureTimeRegex firstMatchInString:time options:0 range:NSMakeRange(0, [time length])])
		return [self dateFromTimeString:time];
	
	NSTextCheckingResult *match = [departureMinutesRegex firstMatchInString:time options:0 range:NSMakeRange(0, [time length])];

	if (match) {
		NSInteger minutes = [[time substringWithRange:[match rangeAtIndex:1]] integerValue];
		return [currentDate dateByAddingTimeInterval:(60 * minutes)];
	}

	assert(false);

	return nil;
}

- (id)init {
    if ((self = [super init])) {
        NSString *sqLiteDb = [[NSBundle mainBundle] pathForResource:@"realtime" ofType:@"sqlite"];
		
		NSLog(@"Opening database");

        if (sqlite3_open([sqLiteDb UTF8String], &database_) != SQLITE_OK) {
            NSLog(@"Failed to open stops database!");
        }
		
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

- (NSArray *)stopInfos {
    
    NSMutableArray *retval = [[NSMutableArray alloc] init];
    NSString *query = @"SELECT id, name FROM stops LIMIT 20";
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database_, [query UTF8String], -1, &statement, nil) 
        == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            int uniqueId = sqlite3_column_int(statement, 0);
            char *nameChars = (char *) sqlite3_column_text(statement, 1);
            NSString *name = [[NSString alloc] initWithUTF8String:nameChars];
            Stop *info = [[Stop alloc] initWithUniqueId:uniqueId name:name distance:0];                        
            [retval addObject:info];
        }
        sqlite3_finalize(statement);
    }
    return retval;
    
}

- (NSArray *)stopsWithLocation:(CLLocation *)location {
    NSMutableArray *retval = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"SELECT id, name, latitude, longitude, ((longitude - %g)*(longitude - %g)*0.259 + (latitude - %g)*(latitude - %g)) as d FROM stops_fts ORDER BY d LIMIT 40", location.coordinate.longitude, location.coordinate.longitude, location.coordinate.latitude, location.coordinate.latitude];
	
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database_, [query UTF8String], -1, &statement, nil) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            int uniqueId = sqlite3_column_int(statement, 0);
            double distance = round([location distanceFromLocation:[[CLLocation alloc] initWithLatitude:sqlite3_column_double(statement, 2) longitude:sqlite3_column_double(statement, 3)]]);
            char *nameChars = (char *) sqlite3_column_text(statement, 1);
            NSString *name = [[NSString alloc] initWithUTF8String:nameChars];
            Stop *info = [[Stop alloc] initWithUniqueId:uniqueId name:name distance:distance];
            [retval addObject:info];
        }
        sqlite3_finalize(statement);
    }
    return retval;
}

- (NSArray *)stopsWithLocation:(CLLocation *)location andName:(NSString *)name {
    NSMutableArray *retval = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"SELECT id, name, latitude, longitude, ((longitude - %g)*(longitude - %g)*0.259 + (latitude - %g)*(latitude - %g)) as d FROM stops_fts WHERE name MATCH '%@*' ORDER BY d LIMIT 40", location.coordinate.longitude, location.coordinate.longitude, location.coordinate.latitude, location.coordinate.latitude, name];
	
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database_, [query UTF8String], -1, &statement, nil) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            int uniqueId = sqlite3_column_int(statement, 0);
            double distance = round([location distanceFromLocation:[[CLLocation alloc] initWithLatitude:sqlite3_column_double(statement, 2) longitude:sqlite3_column_double(statement, 3)]]);
            char *nameChars = (char *) sqlite3_column_text(statement, 1);
            NSString *name = [[NSString alloc] initWithUTF8String:nameChars];
            Stop *info = [[Stop alloc] initWithUniqueId:uniqueId name:name distance:distance];
            [retval addObject:info];
        }
        sqlite3_finalize(statement);
    }
    return retval;
}

- (NSDictionary *)depaturesAtStop:(NSInteger)stop error:(NSError **)error {
	NSMutableDictionary *trafficTypes = [[NSMutableDictionary alloc] init];
	
	//NSError *error = nil;
	
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
		
		currentDate = [self dateFromTimeString:[time substringWithRange:[match rangeAtIndex:1]]];
	}

	for (id typeDom in trafficTypesDom) {
		// Get transport type (metro, buses etc.)
		NSString *typeName;
		for (NSDictionary *attribute in [typeDom objectForKey:@"nodeAttributeArray"]) {
			if ([[attribute objectForKey:@"attributeName"] isEqualToString:@"id"]) {
				//NSLog(@"type: %@", [attribute objectForKey:@"nodeContent"]);
				typeName = [attribute objectForKey:@"nodeContent"];
			}
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

			NSMutableArray *departures = [groups objectForKey:groupName];
			
			if (!departures) {
				departures = [[NSMutableArray alloc] init];
				[groups setValue:departures forKey:groupName];
			}

			for (NSDictionary *d in [[[groupDom objectForKey:@"nodeChildArray"] objectAtIndex:1] objectForKey:@"nodeChildArray"]) {
				// This node can not contain a departure
				if ([[d objectForKey:@"nodeChildArray"] count] < 3)
					continue;

				NSMutableDictionary *departure = [[NSMutableDictionary alloc] init];
	
				NSLog(@"%@ %@", [[[d objectForKey:@"nodeChildArray"] objectAtIndex:1] objectForKey:@"nodeContent"], [[[d objectForKey:@"nodeChildArray"] objectAtIndex:2] objectForKey:@"nodeContent"]);
				
				[departure setValue:[[[d objectForKey:@"nodeChildArray"] objectAtIndex:0] objectForKey:@"nodeContent"] forKey:@"line"];
				[departure setValue:[[[d objectForKey:@"nodeChildArray"] objectAtIndex:1] objectForKey:@"nodeContent"] forKey:@"destination"];
				NSDate *time = [self timeStringToDate:[[[d objectForKey:@"nodeChildArray"] objectAtIndex:2] objectForKey:@"nodeContent"] currentDate:currentDate];
				[departure setValue:time forKey:@"time"];
				[departures addObject:departure];
			}
		}
		
		[trafficTypes setValue:groups forKey:typeName];
	}
	
	// TODO: reenable sorting
	// Sort departures
	/*for (NSString *transportTypeName in trafficTypes) {
		NSDictionary *groups = [trafficTypes objectForKey:transportTypeName];
		for (NSString *groupName in groups) {
			NSArray *group = [groups objectForKey:groupName];
			group = [group sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *d1, NSDictionary *d2) {
				NSDate *time1 = [d1 objectForKey:@"time"];
				NSDate *time2 = [d2 objectForKey:@"time"];
				return [time1 compare:time2];
			}];
			[groups setValue:group forKey:groupName];
		}
	}*/

	return trafficTypes;
}

@end

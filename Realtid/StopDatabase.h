//
//  StopDatabase.h
//  Realtid
//
//  Created by Robert Olsson on 2011-05-08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "/usr/include/sqlite3.h"

@interface StopDatabase : NSObject {
    sqlite3 *database_;

	NSRegularExpression *departureTimeRegex;
	NSRegularExpression *departureMinutesRegex;
	NSRegularExpression *currentTimeRegex;

	NSDateFormatter *timeDateFormatter;
}

+ (StopDatabase*)database;
- (NSArray *)stopInfos;
- (NSArray *)stopsWithLocation:(CLLocation *)location;
- (NSDictionary *)depaturesAtStop:(NSInteger)stop error:(NSError **)error;

@end

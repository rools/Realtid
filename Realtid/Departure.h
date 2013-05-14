//
//  Departure.h
//  Realtid
//
//  Created by Robert Olsson on 5/14/13.
//  Copyright (c) 2013 Robert Olsson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Departure : NSObject {
	NSString *line;
	NSString *destination;
	NSDate *time;
}

@property (copy) NSString *line;
@property (copy) NSString *destination;
@property (copy) NSDate *time;

@end

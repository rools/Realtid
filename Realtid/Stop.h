//
//  StopInfo.h
//  Realtid
//
//  Created by Robert Olsson on 2011-05-08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Stop : NSObject {
    NSInteger identifier;
	NSString *name;
	double distance;
}

@property (assign) NSInteger identifier;
@property (assign) double distance;
@property (copy) NSString *name;

@end

//
//  StopInfo.m
//  Realtid
//
//  Created by Robert Olsson on 2011-05-08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Stop.h"


@implementation Stop

@synthesize uniqueId = _uniqueId;
@synthesize distance = _distance;
@synthesize name = _name;

- (id)initWithUniqueId:(int)uniqueId name:(NSString *)name distance:(double)distance {
    if ((self = [super init])) {
        self.uniqueId = uniqueId;
        self.distance = distance;
        self.name = name;
    }
    return self;
}

- (void) dealloc {
    self.name = nil;  
    //[super dealloc];
}

@end

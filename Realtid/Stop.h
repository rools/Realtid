//
//  StopInfo.h
//  Realtid
//
//  Created by Robert Olsson on 2011-05-08.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Stop : NSObject {
    int uniqueId_;
    double distance_;
    NSString *name_;
}

@property (nonatomic, assign) int uniqueId;
@property (nonatomic, assign) double distance;
@property (nonatomic, copy) NSString *name;

- (id)initWithUniqueId:(int)uniqueId name:(NSString *)name distance:(double)distance;

@end

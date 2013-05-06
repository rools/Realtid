//
//  ViewController.h
//  Realtid
//
//  Created by Robert Olsson on 4/27/13.
//  Copyright (c) 2013 Robert Olsson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface ViewController : UITableViewController <CLLocationManagerDelegate> {
	NSArray *stops;
	CLLocationManager *locationManager;

	NSInteger selectedRowIndex;
	NSInteger selectedStopId;
	
	NSInteger loadingRowIndex;
	NSInteger loadingStopId;
	
	NSDictionary *departures;

	NSTimer *departureTimeUpdateTimer;
}

@property (nonatomic, retain) NSArray *stops;
@property (nonatomic, retain) CLLocationManager *locationManager;

@end

//
//  ViewController.h
//  Realtid
//
//  Created by Robert Olsson on 4/27/13.
//  Copyright (c) 2013 Robert Olsson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "StopCell.h"

@interface ViewController : UITableViewController <CLLocationManagerDelegate, UISearchBarDelegate> {
	NSArray *stops;
	CLLocationManager *locationManager;

	NSInteger selectedRowIndex;
	NSInteger selectedStopId;
	
	NSInteger loadingRowIndex;
	NSInteger loadingStopId;
	
	NSDictionary *departures;
	
	StopCell *selectedCell;

	NSTimer *departureTimeUpdateTimer;
	
	UISearchBar *searchBar;
	
	CLLocation *lastLocation;
	NSString *filterString;
}

@end

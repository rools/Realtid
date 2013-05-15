//
//  ViewController.m
//  Realtid
//
//  Created by Robert Olsson on 4/27/13.
//  Copyright (c) 2013 Robert Olsson. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

#import "ViewController.h"
#import "StopCell.h"
#import "Stop.h"
#include "Departure.h"
#import "StopDatabase.h"
#import "Util.h"
#import "XPathQuery.h"

@interface ViewController ()

@end

@implementation ViewController

+ (NSDictionary *)removePastDepartures:(NSDictionary *)departures {
	NSDate *currentDate = [NSDate date];
	NSMutableDictionary *updatedDepartures = [[NSMutableDictionary alloc] init];

	for (NSString *transportTypeName in departures) {
		NSDictionary *groups = [departures objectForKey:transportTypeName];
		NSMutableDictionary *updatedGroups = [[NSMutableDictionary alloc] init];

		for (NSString *groupName in groups) {			
			NSArray *group = [groups objectForKey:groupName];
			NSMutableArray *updatedGroup = [[NSMutableArray alloc] init];
			
			for (Departure *departure in group) {
				// Add the departure if it didn't occur more than 30 seconds ago
				if ([currentDate timeIntervalSinceDate:departure.time] <= 30)
					[updatedGroup addObject:departure];
			}

			if (updatedGroup.count > 0)
				[updatedGroups setObject:updatedGroup forKey:groupName];
		}
		
		if (groups.count > 0)
			[updatedDepartures setObject:updatedGroups forKey:transportTypeName];

	}
	
	return updatedDepartures;
}

- (void)updateDepartureTimes {
	departures = [ViewController removePastDepartures:departures];

	// Remove selection of stop when there are no remaining departures
	if (departures.count == 0)
		[self unloadDepartures];

	[self reloadList];
}

- (void)startStandardUpdates {
    if (locationManager == nil)
        locationManager = [[CLLocationManager alloc] init];
	
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
	
    // Set a movement threshold for location updates, to avoid list constantly updating
    locationManager.distanceFilter = 500;
	
    [locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	lastLocation = [locations lastObject];
	[self reloadList];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	selectedRowIndex = -1;
	selectedStopId = -1;
	loadingRowIndex = -1;
	loadingStopId = -1;
	
	// Initialize location to Sergels torg
	lastLocation = [[CLLocation alloc] initWithLatitude:59.332063 longitude:18.063798];
    [self reloadList];
	
	// Add search bar
	searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0)];
	searchBar.delegate = self;
	searchBar.backgroundColor = [UIColor blackColor];
	searchBar.barStyle = UIBarStyleBlack;
	searchBar.backgroundImage = nil;
	[searchBar setPlaceholder:NSLocalizedString(@"Search stops", nil)];
	[searchBar sizeToFit];
	for (id view in searchBar.subviews) {
        if ([view isKindOfClass:NSClassFromString(@"UISearchBarBackground")]) {
			[view removeFromSuperview];
        } else if ([view isKindOfClass:[UITextField class]]) {
			UITextField *textField = view;
			[textField setKeyboardAppearance:UIKeyboardAppearanceAlert];
		}
    }
	self.tableView.tableHeaderView = searchBar;

	// Set initial scroll offset just past the search bar
	[self.tableView setContentOffset:CGPointMake(0, searchBar.frame.size.height) animated:NO];

	[self startStandardUpdates];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [stops count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	// TODO: don't reuse selected cells
    static NSString *CellIdentifier = @"StopCell";

    StopCell *cell = (StopCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil)
		cell = [StopCell cell];

    // Set up the cell...
	Stop *stop = [stops objectAtIndex:indexPath.row];

	// Check if selected or loading cell have changed index (can occur when user's location is updated)
	if (selectedStopId == stop.identifier && selectedRowIndex != indexPath.row)
		selectedRowIndex = indexPath.row;
	if (loadingStopId == stop.identifier && loadingRowIndex != indexPath.row)
		loadingRowIndex = indexPath.row;

	[cell loadStop:stop isDeparturesLoading:stop.identifier == loadingStopId];
	if (stop.identifier == selectedStopId)
		[cell loadDepartures:departures];

    return cell;
}

-(void)loadDepartures:(NSInteger)index stopId:(NSInteger)stopId {
	NSMutableArray *rowsToReload = [NSMutableArray arrayWithObject:[NSIndexPath indexPathForRow:index inSection:0]];
	
	if (selectedRowIndex >= 0) {
		[rowsToReload addObject:[NSIndexPath indexPathForRow:selectedRowIndex inSection:0]];
		[self unloadDepartures];
	}
	
	selectedRowIndex = index;
	selectedStopId = stopId;

	// Set up timer that will fire departure time updates
	NSDate *date = [NSDate dateWithTimeInterval:60 sinceDate:[Util currentMinute]];
	departureTimeUpdateTimer = [[NSTimer alloc] initWithFireDate:date interval:60 target:self selector:@selector(updateDepartureTimes) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:departureTimeUpdateTimer forMode:NSDefaultRunLoopMode];

	[[self tableView] reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationNone];
}

-(void)unloadDepartures {
	selectedRowIndex = -1;
	selectedStopId = -1;

	[departureTimeUpdateTimer invalidate];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Hide keyboard
	[self.view endEditing:YES];

	if (indexPath.row == selectedRowIndex) {
		[self unloadDepartures];
		[tableView beginUpdates];
		[[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
		[tableView endUpdates];
	} else {
		Stop *stop = [stops objectAtIndex:indexPath.row];
		
		NSMutableArray *rowsToReload = [NSMutableArray arrayWithObject:indexPath];
		
		if (loadingRowIndex >= 0)
			[rowsToReload addObject:[NSIndexPath indexPathForRow:loadingRowIndex inSection:0]];

		loadingRowIndex = indexPath.row;
		loadingStopId = stop.identifier;
		
		[tableView beginUpdates];
		[self.tableView reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationNone];
		[tableView endUpdates];
		
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
		dispatch_async(queue, ^{
			NSInteger stopId = stop.identifier;
			NSError *error;
			departures = [[StopDatabase database] depaturesAtStop:stop.identifier error:&error];
			dispatch_sync(dispatch_get_main_queue(), ^{
				
				// Check if this stop is the one that was latest pressed
				if (loadingStopId == stopId) {
					[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
					
					NSInteger rowIndex = loadingRowIndex;

					loadingRowIndex = -1;
					loadingStopId = -1;

					[tableView beginUpdates];
					if (departures) {						
						[self loadDepartures:indexPath.row stopId:stop.identifier];
					} else {
						[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:rowIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
						
						NSString *title;
						NSString *message;
						
						title = NSLocalizedString(@"Loading failed", nil);
						
						switch (error.code) {
							case NSFileReadUnknownError:
								message = NSLocalizedString(@"The phone does not seem to have a connection.", nil);
								break;
								
							case NSURLErrorCannotParseResponse:
								message = NSLocalizedString(@"An error occurred with SL's services. Please try again later.", nil);
								break;
								
							default:
								message = NSLocalizedString(@"An error occurred.", nil);
								break;
						}
						
						UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
						[alert show];
					}
					[tableView endUpdates];
				}
			});
		});
	}
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	Stop *stop = [stops objectAtIndex:indexPath.row];
	
	if(stop.identifier == selectedStopId) {
		return 69 + [StopCell cellHeight:departures];
	} else {
		return 69;
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self.view endEditing:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	filterString = searchText;
	[self reloadList];
}

- (void)reloadList {
	loadingRowIndex = -1;
	selectedRowIndex = -1;
	stops = [[StopDatabase database] stopsWithLocation:lastLocation andName:filterString];
	[[self tableView] reloadData];
}

@end

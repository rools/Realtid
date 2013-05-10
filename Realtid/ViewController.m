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
#import "StopDatabase.h"
#import "XPathQuery.h"

const CGFloat DEPARTURE_HEIGHT = 21;
const CGFloat TRANSPORT_SPACING = 20;
const CGFloat GROUP_SPACING = 20;
const CGFloat DEPARTURE_SPACING = 2;

const CGFloat DEPARTURE_NAME_X = 44;
const CGFloat DEPARTURE_NAME_WIDTH = 178;
const CGFloat DEPARTURE_TIME_X = 247;
const CGFloat DEPARTURE_TIME_WIDTH = 56;

const CGFloat GROUP_ICON_X = 8;
const CGFloat GROUP_ICON_SIZE = 32;

const CGFloat MESSAGE_X = 20;
const CGFloat MESSAGE_WIDTH = 202;
const CGFloat MESSAGE_HEIGHT = 30;

//const CGFloat STOP_BOTTOM_PADDING = 14;

const CGFloat MAX_DEPARTURES_PER_GROUP = 4;

@interface ViewController ()

@end

@implementation ViewController

// Get the current date, rounded to previous minute
+ (NSDate *)currentMinute {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	
	NSDateComponents *dateComponents = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:[NSDate date]];
	
	[dateComponents setSecond:0];

	return [calendar dateFromComponents:dateComponents];
}

+ (NSString *)formatDistance:(NSInteger)meters {
	// Round to two significatnt figures
	double n = pow(10, floor(log10(meters)) - 1);
	meters = round(meters / n) * n;

	if (meters < 1e3)
		return [NSString stringWithFormat:@"%i m", meters];
	if (meters > 100e3)
		return @"100+ km";

	double kilometers = meters / 1000.0;
	
	// Always show two significant digits
	if (kilometers < 10.0)
		return [NSString stringWithFormat:@"%.1f km", kilometers];

	return [NSString stringWithFormat:@"%.2g km", kilometers];
}

- (NSString *)formatTime:(NSDate *)date {
	NSTimeInterval interval = [date timeIntervalSinceDate:[ViewController currentMinute]];

	// Show minutes left if the date is within an hour
	if (interval < 3600.0) {
		NSInteger minutes = round(interval / 60);
		if (minutes == 0)
			return @"NU";
		return [NSString stringWithFormat:@"%i min", minutes];
	}
	
	return @"blah";
}

/*- (void)reloadRow:(NSInteger)index {
	NSLog(@"Reloading %i", index
		  );
	//[[self tableView] beginUpdates];
	[[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
	//[[self tableView] endUpdates];
}*/

- (NSInteger)selectedRowHeight {
	NSInteger height = 0;
	
	if ([departures count] == 0)
		return MESSAGE_HEIGHT + 10;

	for (NSString *transportTypeName in departures) {
		NSDictionary *groups = [departures objectForKey:transportTypeName];

		for (NSString *groupName in groups) {
			NSArray *group = [groups objectForKey:groupName];

			height += DEPARTURE_HEIGHT + DEPARTURE_SPACING;
			height += MIN([group count], MAX_DEPARTURES_PER_GROUP) * (DEPARTURE_HEIGHT + DEPARTURE_SPACING);
			height -= DEPARTURE_SPACING;
			height += GROUP_SPACING;
		}
		
		height -= GROUP_SPACING;

		height += TRANSPORT_SPACING;
	}

	return height;
}

- (void)updateDepartureTimes {
	//[[self tableView] reloadData];
	[self reloadList];
}

- (void)startStandardUpdates
{
    // Create the location manager if this object does not
    // already have one.
    if (nil == locationManager)
        locationManager = [[CLLocationManager alloc] init];
	
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
	
    // Set a movement threshold for new events.
    locationManager.distanceFilter = 500;
	
    [locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	lastLocation = [locations lastObject];
	stops = [[StopDatabase database] stopsWithLocation:lastLocation];
	[self reloadList];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	selectedRowIndex = -1;
	selectedStopId = -1;
	loadingRowIndex = -1;
	loadingStopId = -1;
	
	// Initialize location to Sergels torg
	lastLocation = [[CLLocation alloc] initWithLatitude:59.332063 longitude:18.063798];
	stops = [[StopDatabase database] stopsWithLocation:lastLocation];
    [self reloadList];
	
	// Add search bar
	searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 0)];
	searchBar.delegate = self;
	searchBar.backgroundColor = [UIColor blackColor];
	searchBar.barStyle = UIBarStyleBlack;
	searchBar.backgroundImage = nil;
	[searchBar setPlaceholder:@"Sök hållplats"];
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSLog(@"count: %i", [stops count]);
    return [stops count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"StopCell";

    StopCell *cell = (StopCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"StopCell" owner:nil options:nil];
		cell = [topLevelObjects objectAtIndex:0];
    }

    // Set up the cell...
    Stop *info = [stops objectAtIndex:indexPath.row];

	// Check if selected or loading cell have changed index (can occur when user's location is updated)
	if (selectedStopId == info.uniqueId && selectedRowIndex != indexPath.row)
		selectedRowIndex = indexPath.row;
	if (loadingStopId == info.uniqueId && loadingRowIndex != indexPath.row)
		loadingRowIndex = indexPath.row;

    cell.stopLabel.text = info.name;
    cell.distanceLabel.text = [ViewController formatDistance:info.distance];

	UIColor *color;

	UIColor *near = [UIColor colorWithRed:0.0 green:(120.0/256) blue:(23.0 / 256.0) alpha:1.0];
	UIColor *medium = [UIColor colorWithRed:0.8*(254.0 / 256.0) green:0.8*(220.0/256) blue:0.8*(8.0 / 256.0) alpha:1.0];
	UIColor *far = [UIColor colorWithRed:(154.0 / 256.0) green:(1.0/256) blue:(22.0 / 256.0) alpha:1.0];

	const float nearThreshold = 200.0;
	const float mediumThreshold = 800.0;
	const float farThreshold = 2000.0;

	if (info.distance < nearThreshold) {
		color = near;
	} else if (info.distance < mediumThreshold) {
		float c = (info.distance - nearThreshold) / (mediumThreshold - nearThreshold);
		float ci = 1.0 - c;
		CGFloat r1, g1, b1, r2, g2, b2, a;
		[near getRed:&r1 green:&g1 blue:&b1 alpha: &a];
		[medium getRed:&r2 green:&g2 blue:&b2 alpha: &a];
		color = [UIColor colorWithRed:(r1 * ci + r2 * c) green:(g1 * ci + g2 * c) blue:(b1 * ci + b2 * c) alpha:a];
	} else if (info.distance < farThreshold) {
		float c = (info.distance - mediumThreshold) / (farThreshold - mediumThreshold);
		float ci = 1.0 - c;
		CGFloat r1, g1, b1, r2, g2, b2, a;
		[medium getRed:&r1 green:&g1 blue:&b1 alpha: &a];
		[far getRed:&r2 green:&g2 blue:&b2 alpha: &a];
		color = [UIColor colorWithRed:(r1 * ci + r2 * c) green:(g1 * ci + g2 * c) blue:(b1 * ci + b2 * c) alpha:a];
	} else {
		color = far;
	}
		
	if (indexPath.row == loadingRowIndex) {
		CGFloat r, g, b, a;
		[color getRed:&r green:&g blue:&b alpha: &a];
		color = [UIColor colorWithRed:(r * 0.5) green:(g * 0.5) blue:(b * 0.5) alpha:a];
	} /*else if (indexPath.row == selectedIndex) {
		CGFloat r, g, b, a;
		[color getRed:&r green:&g blue:&b alpha: &a];
		color = [UIColor colorWithRed:(r * 0.8) green:(g * 0.8) blue:(b * 0.8) alpha:a];
	}*/
	
	//cell.contentView.backgroundColor = [UIColor colorWithWhite:0.94 alpha:1.0];
	//float c = 0.3*log(info.distance);
	cell.contentView.backgroundColor = color;
	cell.backgroundColor = color;
	cell.backgroundView.backgroundColor = color;
	cell.opaque = YES;
	cell.contentView.opaque = YES;
	cell.backgroundView.opaque = YES;

	CGFloat y = 69;
	if (info.uniqueId == selectedStopId) {
		if ([departures count] > 0) {
			for (NSString *transportTypeName in departures) {
				NSDictionary *groups = [departures objectForKey:transportTypeName];
				
				UIImage *groupImage;
				
				if ([transportTypeName isEqualToString:@"MetroList"])
					groupImage = [UIImage imageNamed:@"subway.png"];
				else if ([transportTypeName isEqualToString:@"BusList"])
					groupImage = [UIImage imageNamed:@"bus.png"];
				else if ([transportTypeName isEqualToString:@"TramList"])
					groupImage = [UIImage imageNamed:@"tram.png"];
				else if ([transportTypeName isEqualToString:@"TrainList"])
					groupImage = [UIImage imageNamed:@"train.png"];
				else
					groupImage = nil;

				for (NSString *groupName in groups) {
					NSArray *group = [groups objectForKey:groupName];

					UILabel *destinationLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEPARTURE_NAME_X, y, DEPARTURE_NAME_WIDTH, DEPARTURE_HEIGHT)];
					destinationLabel.backgroundColor = [UIColor clearColor];
					destinationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
					destinationLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
					[destinationLabel setText:groupName];
					[cell addSubview:destinationLabel];
					y += DEPARTURE_HEIGHT + DEPARTURE_SPACING;
					
					// Group transport icon
					CGFloat iconY = y + 0.5 * (MIN([group count], MAX_DEPARTURES_PER_GROUP) * (DEPARTURE_HEIGHT + DEPARTURE_SPACING) - DEPARTURE_SPACING) - 0.5 * GROUP_ICON_SIZE;
					UIImageView *groupIcon = [[UIImageView alloc] initWithFrame:CGRectMake(GROUP_ICON_X, iconY, 32, 32)];
					groupIcon.image = groupImage;
					groupIcon.contentMode = UIViewContentModeCenter;
					[cell addSubview:groupIcon];
					
					int departureCount = 0;

					for (NSDictionary *departure in group) {
						if (departureCount >= MAX_DEPARTURES_PER_GROUP)
							break;

						// Destination label
						NSString *destination = [NSString stringWithFormat:@"%@ %@", [departure objectForKey:@"line"], [departure objectForKey:@"destination"]];
						UILabel *destinationLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEPARTURE_NAME_X, y, DEPARTURE_NAME_WIDTH, DEPARTURE_HEIGHT)];
						destinationLabel.backgroundColor = [UIColor clearColor];
						destinationLabel.textColor = [UIColor whiteColor];
						destinationLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
						[destinationLabel setText:destination];
						[cell addSubview:destinationLabel];

						// Time label
						UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(DEPARTURE_TIME_X, y, DEPARTURE_TIME_WIDTH, DEPARTURE_HEIGHT)];
						timeLabel.backgroundColor = [UIColor clearColor];
						timeLabel.textColor = [UIColor whiteColor];
						timeLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
						timeLabel.textAlignment = NSTextAlignmentRight;
						[timeLabel setText:[self formatTime:[departure objectForKey:@"time"]]];
						[cell addSubview:timeLabel];
						
						y += DEPARTURE_HEIGHT + DEPARTURE_SPACING;
						
						departureCount++;
					}
					
					y -= DEPARTURE_SPACING;

					y += GROUP_SPACING;
				}
				y -= GROUP_SPACING;

				y += TRANSPORT_SPACING;
			}
		} else {
			// Currently no available departures for this stop
			UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(MESSAGE_X, y, MESSAGE_WIDTH, MESSAGE_HEIGHT)];
			messageLabel.backgroundColor = [UIColor clearColor];
			messageLabel.textColor = [UIColor whiteColor];
			messageLabel.font = [UIFont fontWithName:@"Avenir Next Condensed" size:18];
			messageLabel.textAlignment = NSTextAlignmentCenter;
			[messageLabel setText:@"Inga avgångar"];
			[cell addSubview:messageLabel];
		}
	}

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
	NSDate *date = [NSDate dateWithTimeInterval:60 sinceDate:[ViewController currentMinute]];
	departureTimeUpdateTimer = [[NSTimer alloc] initWithFireDate:date interval:60 target:self selector:@selector(updateDepartureTimes) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:departureTimeUpdateTimer forMode:NSDefaultRunLoopMode];
	
	UITableViewCell *cell = [[self tableView] cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
	//[self tableView].backgroundColor = cell.contentView.backgroundColor;

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
		loadingStopId = stop.uniqueId;
		
		[tableView beginUpdates];
		[[self tableView] reloadRowsAtIndexPaths:rowsToReload withRowAnimation:UITableViewRowAnimationNone];
		//[self reloadRow:loadingRowIndex];
		[tableView endUpdates];
		
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
		dispatch_async(queue, ^{
			NSInteger stopId = stop.uniqueId;
			//sleep(10);
			NSError *error;
			departures = [[StopDatabase database] depaturesAtStop:stop.uniqueId error:&error];
			dispatch_sync(dispatch_get_main_queue(), ^{
				
				// Check if this stop is the one that was latest pressed
				if (loadingStopId == stopId) {
					[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
					
					NSInteger rowIndex = loadingRowIndex;

					loadingRowIndex = -1;
					loadingStopId = -1;

					[tableView beginUpdates];
					if (departures) {						

						[self loadDepartures:indexPath.row stopId:stop.uniqueId];
						
					} else {
						[[self tableView] reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:rowIndex inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
						
						NSString *title;
						NSString *message;
						
						title = @"Laddning misslyckades";
						
						switch (error.code) {
							case NSFileReadUnknownError:
								message = @"Du verkar inte vara uppkopplad.";
								break;
								
							case NSURLErrorCannotParseResponse:
								message = @"Fel med SL:s tjänst. Försök igen senare.";
								break;
								
							default:
								message = @"Ett fel uppstod.";
								break;
						}
						
						UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
						[alert show];
					}
					[tableView endUpdates];
				}
			});
		});
	}
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    //If this is the selected index we need to return the height of the cell
    //in relation to the label height otherwise we just return the minimum label height with padding
	
	Stop *stop = [stops objectAtIndex:indexPath.row];
	
	if(stop.uniqueId == selectedStopId) {
		NSLog(@"i:%i h:%i", indexPath.row, 69 + [self selectedRowHeight]);
		return 69 + [self selectedRowHeight];
	} else {
		NSLog(@"i:%i h:%i", indexPath.row, 69);
		return 69;
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self.view endEditing:YES];
	//[self tableView].backgroundColor = [UIColor blackColor];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	filterString = searchText;
	[self reloadList];
}

- (void)reloadList {
	if ([filterString length] > 0)
		stops = [[StopDatabase database] stopsWithLocation:lastLocation andName:filterString];
	else
		stops = [[StopDatabase database] stopsWithLocation:lastLocation];
	
	[[self tableView] reloadData];
}

@end

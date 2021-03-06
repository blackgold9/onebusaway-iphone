/**
 * Copyright (C) 2009 bdferris <bdferris@onebusaway.org>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific languOBAStopSectionTypeage governing permissions and
 * limitations under the License.
 */

#import "OBAGenericStopViewController.h"
#import "OBALogger.h"

#import "OBAArrivalEntryTableViewCell.h"

#import "OBAProgressIndicatorView.h"

#import "OBAPresentation.h"

#import "OBAStopPreferences.h"
#import "OBAEditStopBookmarkViewController.h"
#import "OBAEditStopPreferencesViewController.h"
#import "OBAArrivalAndDepartureViewController.h"
#import "OBATripDetailsViewController.h"
#import "OBAReportProblemViewController.h"

#import "OBASearchController.h"
#import "OBASphericalGeometryLibrary.h"
#import "MKMapView+oba_Additions.h"

static const double kNearbyStopRadius = 200;

@interface OBAGenericStopViewController ()
@property(strong,readwrite) OBAApplicationContext * _appContext;
@property(strong,readwrite) NSString * stopId;
@property NSUInteger minutesAfter;

@property(strong) id<OBAModelServiceRequest> request;
@property(strong) NSTimer *timer;

@property(strong) OBAArrivalsAndDeparturesForStopV2 * result;

@property(strong) OBAProgressIndicatorView * progressView;
@property(strong) OBAServiceAlertsModel * serviceAlerts;
@end

@interface OBAGenericStopViewController (Private)

// Override point for extension classes
- (void)customSetup;

- (void)refresh;
- (void)clearPendingRequest;
- (void)didBeginRefresh;
- (void)didFinishRefresh;


- (NSUInteger) sectionIndexForSectionType:(OBAStopSectionType)section;

- (UITableViewCell*) tableView:(UITableView*)tableView serviceAlertCellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell*) tableView:(UITableView*)tableView predictedArrivalCellForRowAtIndexPath:(NSIndexPath*)indexPath;
- (void)determineFilterTypeCellText:(UITableViewCell*)filterTypeCell filteringEnabled:(bool)filteringEnabled;
- (UITableViewCell*) tableView:(UITableView*)tableView filterCellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell*) tableView:(UITableView*)tableView actionCellForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)tableView:(UITableView *)tableView didSelectServiceAlertRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectTripRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectActionRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)reloadData;
@end


@implementation OBAGenericStopViewController

- (id) initWithApplicationContext:(OBAApplicationContext*)appContext {

	if (self = [super initWithStyle:UITableViewStyleGrouped]) {

		_appContext = appContext;
		
		_minutesBefore = 5;
		_minutesAfter = 35;
		
		_showTitle = YES;
		_showServiceAlerts = YES;
		_showActions = YES;
		
		_arrivalCellFactory = [[OBAArrivalEntryTableViewCellFactory alloc] initWithAppContext:_appContext tableView:self.tableView];
		_arrivalCellFactory.showServiceAlerts = YES;

		_serviceAlerts = [[OBAServiceAlertsModel alloc] init];

		_progressView = [[OBAProgressIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 160, 33)];
		[self.navigationItem setTitleView:_progressView];
		
		UIBarButtonItem * refreshItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(onRefreshButton:)];
		[self.navigationItem setRightBarButtonItem:refreshItem];
		
		_allArrivals = [[NSMutableArray alloc] init];
		_filteredArrivals = [[NSMutableArray alloc] init];
		_showFilteredArrivals = YES;
		
		self.navigationItem.title = NSLocalizedString(@"Stop",@"stop");
		
		[self customSetup];
	}
	return self;
}

- (id) initWithApplicationContext:(OBAApplicationContext*)appContext stopId:(NSString*)stopId {
	if (self = [self initWithApplicationContext:appContext]) {
        self.stopId = stopId;
	}
	return self;
}

- (void) dealloc {
	[self clearPendingRequest];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.showTitle) {
        UINib *xibFile = [UINib nibWithNibName:@"OBAGenericStopViewController" bundle:nil];
        [xibFile instantiateWithOwner:self options:nil];
        
        self.tableHeaderView.backgroundColor = self.tableView.backgroundColor;        
        self.tableView.tableHeaderView = self.tableHeaderView;
    }
}

- (void)viewDidUnload {
    self.tableHeaderView = nil;
    self.tableView.tableHeaderView = nil;
    
    [super viewDidUnload];
}

- (OBAStopSectionType) sectionTypeForSection:(NSUInteger)section {

	if (_result.stop) {
		
		int offset = 0;
				
		if( _showServiceAlerts && _serviceAlerts.unreadCount > 0) {
			
			if( section == offset )
				return OBAStopSectionTypeServiceAlerts;
			offset++;
		}
		
		if( section == offset ) {
			return OBAStopSectionTypeArrivals;
		}
		offset++;
		
		if( [_filteredArrivals count] != [_allArrivals count] ) {
			if( section == offset )
				return OBAStopSectionTypeFilter;
			offset++;
		}
		
		if( _showActions ) {
			if( section == offset)
				return OBAStopSectionTypeActions;
			offset++;
		}
	}
	
	return OBAStopSectionTypeNone;
}

#pragma mark OBANavigationTargetAware

- (OBANavigationTarget*) navigationTarget {
	NSDictionary * params = @{@"stopId": _stopId};
	return [OBANavigationTarget target:OBANavigationTargetTypeStop parameters:params];
}


- (void) setNavigationTarget:(OBANavigationTarget*)navigationTarget {
    self.stopId = [navigationTarget parameterForKey:@"stopId"];
	[self refresh];
}

#pragma mark UIViewController

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	
	[self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
 
	[self clearPendingRequest];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)willEnterForeground {
	// will repaint the UITableView to update new time offsets and such when returning from the background.
	// this makes it so old data, represented with current times, from before the task switch will display
	// briefly before we fetch new data.
	[self reloadData];
}

#pragma mark OBAModelServiceDelegate

- (void)requestDidFinish:(id<OBAModelServiceRequest>)request withObject:(id)obj context:(id)context {
	NSString * message = [NSString stringWithFormat:@"%@: %@",NSLocalizedString(@"Updated",@"message"), [OBACommon getTimeAsString]];
	[_progressView setMessage:message inProgress:NO progress:0];
	[self didFinishRefresh];
    self.result = obj;
	
	// Note the event
    [[NSNotificationCenter defaultCenter] postNotificationName:OBAViewedArrivalsAndDeparturesForStopNotification object:self.result.stop];

	[self reloadData];
}

- (void)requestDidFinish:(id<OBAModelServiceRequest>)request withCode:(NSInteger)code context:(id)context {
    NSString *message = (404 == code ? NSLocalizedString(@"Stop not found",@"code == 404") : NSLocalizedString(@"Unknown error",@"code # 404"));
    [self.progressView setMessage:message inProgress:NO progress:0];
	[self didFinishRefresh];
}

- (void)requestDidFail:(id<OBAModelServiceRequest>)request withError:(NSError *)error context:(id)context {
	OBALogWarningWithError(error, @"Error... yay!");
	[_progressView setMessage:NSLocalizedString(@"Error connecting",@"requestDidFail") inProgress:NO progress:0];
	[self didFinishRefresh];
}

- (void)request:(id<OBAModelServiceRequest>)request withProgress:(float)progress context:(id)context {
	[_progressView setInProgress:YES progress:progress];
}

#pragma mark - UITableViewDelegate and UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	
	OBAStopV2 * stop = _result.stop;
	
	if( stop ) {
		int count = 2;
		if( [_filteredArrivals count] != [_allArrivals count] )
			count++;
		if( _showServiceAlerts && _serviceAlerts.unreadCount > 0 )
			count++;
		return count;
	}
	
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
	switch ([self sectionTypeForSection:section]) {
		case OBAStopSectionTypeServiceAlerts: {
            return 1;
        }
		case OBAStopSectionTypeArrivals: {
            NSInteger arrivalRows = self.showFilteredArrivals ? self.filteredArrivals.count : self.allArrivals.count;
            if (arrivalRows > 0) {
                return arrivalRows;
            }
            else {
                // for a 'no arrivals in the next 30 minutes' message
                return 1;
            }
		}
		case OBAStopSectionTypeFilter: {
            return 1;
        }
		case OBAStopSectionTypeActions: {
            return 5;
        }
		default: {
            return 0;
        }
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	switch ([self sectionTypeForSection:indexPath.section]) {
		case OBAStopSectionTypeServiceAlerts: {
			return [self tableView:tableView serviceAlertCellForRowAtIndexPath:indexPath];
        }
		case OBAStopSectionTypeArrivals: {
            return [self tableView:tableView predictedArrivalCellForRowAtIndexPath:indexPath];
        }
		case OBAStopSectionTypeFilter: {
            return [self tableView:tableView filterCellForRowAtIndexPath:indexPath];
        }
		case OBAStopSectionTypeActions: {
            return [self tableView:tableView actionCellForRowAtIndexPath:indexPath];
        }
		default: {
            return [UITableViewCell getOrCreateCellForTableView:tableView];
        }
	}
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	OBAStopSectionType sectionType = [self sectionTypeForSection:indexPath.section];
	
	switch (sectionType) {
			
		case OBAStopSectionTypeServiceAlerts:
			[self tableView:tableView didSelectServiceAlertRowAtIndexPath:indexPath];
			break;
			
		case OBAStopSectionTypeArrivals:
			[self tableView:tableView didSelectTripRowAtIndexPath:indexPath];
			break;
			
		case OBAStopSectionTypeFilter: {
			_showFilteredArrivals = !_showFilteredArrivals;
			
			// update arrivals section
			int arrivalsViewSection = [self sectionIndexForSectionType:OBAStopSectionTypeArrivals];

			UITableViewCell * cell = [tableView cellForRowAtIndexPath:indexPath];
			[self determineFilterTypeCellText:cell filteringEnabled:_showFilteredArrivals];
			[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
			
			if ([_filteredArrivals count] == 0)
			{
				// We're showing a "no arrivals in the next 30 minutes" message, so our insertion/deletion math below would be wrong.
				// Instead, just refresh the section with a fade.
				[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:arrivalsViewSection] withRowAnimation:UITableViewRowAnimationFade];
			}
			else if ([_allArrivals count] != [_filteredArrivals count])
			{
				// Display a nice animation of the cells when changing our filter settings
				NSMutableArray *modificationArray = [NSMutableArray array];
                
                for (NSInteger i = 0; i < self.allArrivals.count; i++) {
                    OBAArrivalAndDepartureV2 * pa = self.allArrivals[i];
                    if (![_filteredArrivals containsObject:pa]) {
						[modificationArray addObject:[NSIndexPath indexPathForRow:i inSection:arrivalsViewSection]];
					}
                }

				if (self.showFilteredArrivals) {
					[self.tableView deleteRowsAtIndexPaths:modificationArray withRowAnimation:UITableViewRowAnimationFade];
                }
				else {
					[self.tableView insertRowsAtIndexPaths:modificationArray withRowAnimation:UITableViewRowAnimationFade];
                }
			}
			
			break;
		}
		
		case OBAStopSectionTypeActions:
			[self tableView:tableView didSelectActionRowAtIndexPath:indexPath];
			break;

		default:
			break;
	}
}

@end


@implementation OBAGenericStopViewController (Private)

- (void) customSetup {
	
}

- (void) refresh {
	[_progressView setMessage:NSLocalizedString(@"Updating...",@"refresh") inProgress:YES progress:0];
	[self didBeginRefresh];
	
	[self clearPendingRequest];
	_request = [_appContext.modelService requestStopWithArrivalsAndDeparturesForId:_stopId withMinutesBefore:_minutesBefore withMinutesAfter:_minutesAfter withDelegate:self withContext:nil];
	_timer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}
	 
- (void) clearPendingRequest {
	
	[_timer invalidate];
	_timer = nil;
	
	[_request cancel];
	_request = nil;
}

- (void) didBeginRefresh {
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void) didFinishRefresh {
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

- (NSUInteger) sectionIndexForSectionType:(OBAStopSectionType)section {

	OBAStopV2 * stop = _result.stop;
	
	if( stop ) {
		
		int offset = 0;
				
		if( _showServiceAlerts && _serviceAlerts.unreadCount > 0) {
			if( section == OBAStopSectionTypeServiceAlerts )
				return offset;
			offset++;
		}
		
		if( section == OBAStopSectionTypeArrivals )
			return offset;
		offset++;
		
		if( [_filteredArrivals count] != [_allArrivals count] ) {
			if( section == OBAStopSectionTypeFilter )
				return offset;
			offset++;
		}
		
		if( _showActions ) {
			if( section == OBAStopSectionTypeActions)
				return offset;
			offset++;
		}
	}
	
	return 0;
	
}

- (UITableViewCell*) tableView:(UITableView*)tableView serviceAlertCellForRowAtIndexPath:(NSIndexPath *)indexPath {	
	return [OBAPresentation tableViewCellForUnreadServiceAlerts:_serviceAlerts tableView:tableView];
}

- (UITableViewCell*)tableView:(UITableView*)tableView predictedArrivalCellForRowAtIndexPath:(NSIndexPath*)indexPath {
	NSArray * arrivals = _showFilteredArrivals ? _filteredArrivals : _allArrivals;
	
	if( [arrivals count] == 0 ) {
		UITableViewCell * cell = [UITableViewCell getOrCreateCellForTableView:tableView];
		cell.textLabel.text = NSLocalizedString(@"No arrivals in the next 30 minutes",@"[arrivals count] == 0");
		cell.textLabel.textAlignment = UITextAlignmentCenter;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
		return cell;
	}
	else {

		OBAArrivalAndDepartureV2 * pa = arrivals[indexPath.row];
		OBAArrivalEntryTableViewCell * cell = [_arrivalCellFactory createCellForArrivalAndDeparture:pa];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}
}


- (void)determineFilterTypeCellText:(UITableViewCell*)filterTypeCell filteringEnabled:(bool)filteringEnabled {
	if( filteringEnabled )
		filterTypeCell.textLabel.text = NSLocalizedString(@"Show all arrivals",@"filteringEnabled");
	else
		filterTypeCell.textLabel.text = NSLocalizedString(@"Show filtered arrivals",@"!filteringEnabled");	
}

- (UITableViewCell*) tableView:(UITableView*)tableView filterCellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	UITableViewCell * cell = [UITableViewCell getOrCreateCellForTableView:tableView];
	
	[self determineFilterTypeCellText:cell filteringEnabled:_showFilteredArrivals];
	
	cell.textLabel.textAlignment = UITextAlignmentCenter;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	return cell;
}

- (UITableViewCell*) tableView:(UITableView*)tableView actionCellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if( indexPath.row == 2 )
		return [OBAPresentation tableViewCellForServiceAlerts:_serviceAlerts tableView:tableView];
		
	UITableViewCell * cell = [UITableViewCell getOrCreateCellForTableView:tableView];

    cell.textLabel.textAlignment = UITextAlignmentCenter;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	switch(indexPath.row) {
		case 0:
			cell.textLabel.text = NSLocalizedString(@"Add to Bookmarks",@"case 0");
			break;
		case 1:
			cell.textLabel.text = NSLocalizedString(@"Filter & Sort Routes",@"case 1");
			break;
		case 2:
			cell.textLabel.text = NSLocalizedString(@"Service Alerts",@"case 2");
			break;
		case 3:
			cell.textLabel.text = NSLocalizedString(@"See Nearby Stops",@"case 3");
			break;
		case 4:
			cell.textLabel.text = NSLocalizedString(@"Report a Problem",@"self.navigationItem.title");
			break;			
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectServiceAlertRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray * situations = _result.situations;
	[OBAPresentation showSituations:situations withAppContext:_appContext navigationController:self.navigationController args:nil];
}

- (void)tableView:(UITableView *)tableView didSelectTripRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray * arrivals = _showFilteredArrivals ? _filteredArrivals : _allArrivals;
	if ( 0 <= indexPath.row && indexPath.row < [arrivals count] ) {
		OBAArrivalAndDepartureV2 * arrivalAndDeparture = arrivals[indexPath.row];
		OBAArrivalAndDepartureViewController * vc = [[OBAArrivalAndDepartureViewController alloc] initWithApplicationContext:_appContext arrivalAndDeparture:arrivalAndDeparture];
		[self.navigationController pushViewController:vc animated:YES];
	}
}

- (void)tableView:(UITableView *)tableView didSelectActionRowAtIndexPath:(NSIndexPath *)indexPath {
	switch(indexPath.row) {
		case 0: {
			OBABookmarkV2 * bookmark = [_appContext.modelDao createTransientBookmark:_result.stop];
			
			OBAEditStopBookmarkViewController * vc = [[OBAEditStopBookmarkViewController alloc] initWithApplicationContext:_appContext bookmark:bookmark editType:OBABookmarkEditNew];
			[self.navigationController pushViewController:vc animated:YES];
			
			break;
		}
			
		case 1: {
			OBAEditStopPreferencesViewController * vc = [[OBAEditStopPreferencesViewController alloc] initWithApplicationContext:_appContext stop:_result.stop];
			[self.navigationController pushViewController:vc animated:YES];
			
			break;
		}
			
		case 2: {
			NSArray * situations = _result.situations;
			[OBAPresentation showSituations:situations withAppContext:_appContext navigationController:self.navigationController args:nil];
			break;
		}
			
		case 3: {
			OBAStopV2 * stop = _result.stop;
			MKCoordinateRegion region = [OBASphericalGeometryLibrary createRegionWithCenter:stop.coordinate latRadius:kNearbyStopRadius lonRadius:kNearbyStopRadius];
			OBANavigationTarget * target = [OBASearch getNavigationTargetForSearchLocationRegion:region];
			[_appContext navigateToTarget:target];
			break;
		}
			
		case 4: {
			OBAReportProblemViewController * vc = [[OBAReportProblemViewController alloc] initWithApplicationContext:_appContext stop:_result.stop];
			[self.navigationController pushViewController:vc animated:YES];
			
			break;
		}
	}
	
}

- (IBAction)onRefreshButton:(id)sender {
	[self refresh];
}

NSComparisonResult predictedArrivalSortByDepartureTime(id pa1, id pa2, void * context) {
	return ((OBAArrivalAndDepartureV2*)pa1).bestDepartureTime - ((OBAArrivalAndDepartureV2*)pa2).bestDepartureTime;
}

NSComparisonResult predictedArrivalSortByRoute(id o1, id o2, void * context) {
	OBAArrivalAndDepartureV2* pa1 = o1;
	OBAArrivalAndDepartureV2* pa2 = o2;
	
	OBARouteV2 * r1 = pa1.route;
	OBARouteV2 * r2 = pa2.route;
	NSComparisonResult r = [r1 compareUsingName:r2];
	
	if( r == 0)
		r = predictedArrivalSortByDepartureTime(pa1,pa2,context);
	
	return r;
}

- (void) reloadData {
		
	OBAModelDAO * modelDao = _appContext.modelDao;
    
    //TODO: use data from this to populate a small map.
	OBAStopV2 * stop = _result.stop;
	
	NSArray * predictedArrivals = _result.arrivalsAndDepartures;
	
	[_allArrivals removeAllObjects];
	[_filteredArrivals removeAllObjects];
    
    if (stop) {
        [self.mapView oba_setCenterCoordinate:CLLocationCoordinate2DMake(stop.lat, stop.lon) zoomLevel:13 animated:NO];
        self.stopName.text = stop.name;
        if (stop.direction) {
            self.stopNumber.text = [NSString stringWithFormat:@"%@ # %@ - %@ %@",NSLocalizedString(@"Stop",@"text"),stop.code,stop.direction,NSLocalizedString(@"bound",@"text")];
        }
        else {
           self.stopNumber.text = [NSString stringWithFormat:@"%@ # %@",NSLocalizedString(@"Stop",@"text"),stop.code];
        }
    }
	
	if (stop && predictedArrivals) {
		
		OBAStopPreferencesV2 * prefs = [modelDao stopPreferencesForStopWithId:stop.stopId];
		
		for( OBAArrivalAndDepartureV2 * pa in predictedArrivals) {
			[_allArrivals addObject:pa];
			if( [prefs isRouteIdEnabled:pa.routeId] )
				[_filteredArrivals addObject:pa];
		}
		
		switch (prefs.sortTripsByType) {
			case OBASortTripsByDepartureTimeV2:
				[_allArrivals sortUsingFunction:predictedArrivalSortByDepartureTime context:nil];
				[_filteredArrivals sortUsingFunction:predictedArrivalSortByDepartureTime context:nil];
				break;
			case OBASortTripsByRouteNameV2:
				[_allArrivals sortUsingFunction:predictedArrivalSortByRoute context:nil];
				[_filteredArrivals sortUsingFunction:predictedArrivalSortByRoute context:nil];
				break;
		}
	}
	
	_serviceAlerts = [modelDao getServiceAlertsModelForSituations:_result.situations];
	
	[self.tableView reloadData];
}

@end



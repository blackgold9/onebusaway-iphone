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
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "OBAApplicationContext.h"
#import "OBANavigationTargetAware.h"
#import "OBAStop.h"
#import "OBALocationManager.h"
#import "OBASearchController.h"
#import "OBALocationManager.h"
#import "OBAGenericAnnotation.h"
#import "OBANetworkErrorAlertViewDelegate.h"
#import "OBASearchResultsMapFilterToolbar.h"
#import "OBAMapRegionManager.h"
#import "OBAScopeView.h"

@class OBASearchControllerImpl;

@interface OBASearchResultsMapViewController : UIViewController <OBANavigationTargetAware,OBASearchControllerDelegate, MKMapViewDelegate,UIActionSheetDelegate,UIAlertViewDelegate,OBALocationManagerDelegate,OBAProgressIndicatorDelegate, UISearchBarDelegate> {
	
	OBAApplicationContext * _appContext;
	
	OBASearchController * _searchController;
	
	MKMapView * _mapView;
    OBAMapRegionManager * _mapRegionManager;
    
	UIBarButtonItem * _currentLocationButton;
	UIBarButtonItem * _listButton;
    OBASearchResultsMapFilterToolbar * _filterToolbar;

	OBAGenericAnnotation * _locationAnnotation;
	
	UIActivityIndicatorView * _activityIndicatorView;
	OBANetworkErrorAlertViewDelegate * _networkErrorAlertViewDelegate;
	
	MKCoordinateRegion _mostRecentRegion;
	CLLocation * _mostRecentLocation;
	
	NSTimer * _refreshTimer;
	
	BOOL _hideFutureNetworkErrors;
}
@property(nonatomic,strong) OBAApplicationContext * appContext;
@property(nonatomic,strong) IBOutlet OBAScopeView *scopeView;
@property(nonatomic,strong) IBOutlet UISegmentedControl *searchTypeSegmentedControl;
@property(nonatomic,strong) IBOutlet MKMapView * mapView;
@property(nonatomic,strong) IBOutlet UIBarButtonItem * currentLocationButton;
@property(nonatomic,strong) IBOutlet UISearchBar *searchBar;
@property(nonatomic,strong) IBOutlet UIToolbar *toolbar;

@property (nonatomic,strong) OBASearchResultsMapFilterToolbar * filterToolbar;

- (IBAction)onCrossHairsButton:(id)sender;
- (IBAction)onListButton:(id)sender;

@end

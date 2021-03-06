#import "OBAApplicationContext.h"
#import "OBATripDetailsV2.h"
#import "OBATripInstanceRef.h"
#import "OBAProgressIndicatorView.h"


@interface OBATripScheduleMapViewController : UIViewController <MKMapViewDelegate,OBAModelServiceDelegate> {
	OBAApplicationContext * _appContext;
	OBATripInstanceRef * _tripInstance;
	NSString * _currentStopId;
	OBATripDetailsV2 * _tripDetails;
	id<OBAModelServiceRequest> _request;
	OBAProgressIndicatorView * _progressView;	
	NSDateFormatter * _timeFormatter;
	
	MKPolyline * _routePolyline;
	MKPolylineView * _routePolylineView;
}

+(OBATripScheduleMapViewController*) loadFromNibWithAppContext:(OBAApplicationContext*)context;

@property (nonatomic,strong) IBOutlet OBAApplicationContext * appContext;
@property (nonatomic,strong) IBOutlet OBAProgressIndicatorView * progressView;
@property (nonatomic,strong) OBATripInstanceRef * tripInstance;
@property (nonatomic,strong) OBATripDetailsV2 * tripDetails;
@property (nonatomic,strong) NSString * currentStopId;

- (IBAction) showList:(id)source;

@end

#import "OBAApplicationContext.h"


@interface OBASituationsViewController : UITableViewController {
	OBAApplicationContext * _appContext;
	NSArray * _situations;
}

- (id) initWithApplicationContext:(OBAApplicationContext*)appContext situations:(NSArray*)situations;

@property (nonatomic,strong) NSDictionary * args;

@end

//
//  OBAInfoViewController.h
//  org.onebusaway.iphone
//
//  Created by Aaron Brethorst on 9/17/12.
//
//

#import <UIKit/UIKit.h>

@interface OBAInfoViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
@property(nonatomic,strong) IBOutlet UIView *headerView;
@property(nonatomic,strong) IBOutlet UITableView *tableView;
@property(nonatomic,assign) UIViewController *presenterViewController;
@end

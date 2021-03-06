//
//  homeVC.m
//  iBank
//
//  Created by McKee on 15/4/18.
//  Copyright (c) 2015年 McKee. All rights reserved.
//

#import "homeVC.h"
#import "qryOrgBankBalanceService.h"
#import "qryMyFavoriteService.h"
#import "getMyInfoService.h"
#import "qryMsgListService.h"
#import "logoutService.h"
#import "Utility.h"
#import "homeCell.h"
#import "detailVC.h"
#import "indicatorView.h"
#import "dataHelper.h"
#import "msgVC.h"
#import "sendMsgVC.h"
#import "msgListVC.h"
#import <QuartzCore/QuartzCore.h>
#import "SRRefreshView.h"
#import "userInfoVC.h"

@implementation homeItem
@end

@implementation homeCurrency
@end

@implementation homeBank

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if( self ){
        _currentcies = [[NSMutableArray alloc] initWithCapacity:0];
        _Id = [dict objectForKey:@"bid"];
        _name = [dict objectForKey:@"bank"];
        _rmb = 0.00;
        _dollar = 0.00;
        NSString *balance = [dict objectForKey:@"amount"];
        NSString *code = [dict objectForKey:@"ccode"];
        if( [code isEqualToString:@"RMB"] ){
            _rmb = balance.floatValue;
        }
        else if( [code isEqualToString:@"USD"] ){
            _dollar = balance.floatValue;
        }
    }
    
    return self;
}

@end

@implementation homeOrg

- (instancetype)init
{
    self = [super init];
    if( self ){
        _banks = [[NSMutableArray alloc] initWithCapacity:0];
        _items = [[NSMutableArray alloc] initWithCapacity:0];
        _currentcies = [[NSMutableArray alloc] initWithCapacity:0];
    }    
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    self = [self init];
    if( self ){
        _Id = [dict objectForKey:@"oid"];
        _name = [dict objectForKey:@"org"];
        _rmb = 0.00;
        _dollar = 0.00;
    }
    return self;
}

- (void)addBank:(homeBank *)bank
{
    _rmb += bank.rmb;
    _dollar += bank.dollar;
    for( homeBank *item in _banks ){
        if( [item.Id isEqualToString:bank.Id] ){
            item.rmb += bank.rmb;
            item.dollar += bank.dollar;
            return;
        }
    }
    [_banks addObject:bank];
}

- (void)add:(NSDictionary*)dict
{
    homeBank *bank = [[homeBank alloc] initWithDictionary:dict];
    [self addBank:bank];
}

@end



@implementation favoriteCell
@end



@interface homeVC ()<UITableViewDataSource,UITableViewDelegate,UIAlertViewDelegate,SRRefreshDelegate>
{
    IBOutlet UITableView *_leftTableView;
    IBOutlet UITableView *_rightTableView;
    qryOrgBankBalanceService *_balanceSrv;
    getMyInfoService *_infoSrv;
    qryMyFavoriteService *_favoriteSrv;
    qryMsgListService *_qryUserMsgListSrv;
    qryMsgListService *_qrySystemMsgListSrv;
    NSMutableArray *_orgs;
    NSArray *_favoriteAccounts;
    UIPopoverController *_pop;
}

@property NSMutableArray *orgs;
@property NSArray *favoriteAccounts;
@property UITableView *leftTableView;
@property UITableView *rightTableView;
@property IBOutlet UILabel *userInfoLabel;
@property IBOutlet UILabel *dayInfoLabel;
@property IBOutlet UIView *userInfoView;
@property IBOutlet UIButton *systemMsgButton;
@property IBOutlet UIButton *portraitButton;
@property IBOutlet UIButton *nickNameButton;
@property IBOutlet UILabel *badgeLabel;
@property UIAlertView *logoutAlert;
@property BOOL balanceIsRefreshing;
@property BOOL favoritesIsRefreshing;
@property SRRefreshView *balanceRefreshingView;
@property SRRefreshView *favoritesRefreshingView;
@end

@implementation homeVC

+ (instancetype)viewController
{
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    homeVC * vc = [storyBoard  instantiateViewControllerWithIdentifier:@"homeVC"];
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _badgeLabel.layer.cornerRadius = 8;
    _badgeLabel.layer.masksToBounds = YES;
    _badgeLabel.hidden = YES;
    [dataHelper helper].badgeLabel = _badgeLabel;
    _balanceRefreshingView = [[SRRefreshView alloc] init];
    _balanceRefreshingView.delegate = self;
    _balanceRefreshingView.upInset = 0;
    _balanceRefreshingView.slimeMissWhenGoingBack = YES;
    _balanceRefreshingView.slime.bodyColor = [UIColor grayColor];
    _balanceRefreshingView.slime.skinColor = [UIColor grayColor];
    _balanceRefreshingView.slime.lineWith = 0;
    _balanceRefreshingView.slime.shadowBlur = 2;
    _balanceRefreshingView.slime.shadowColor = [UIColor blackColor];
    [_leftTableView addSubview:_balanceRefreshingView];
    
    _favoritesRefreshingView = [[SRRefreshView alloc] init];
    _favoritesRefreshingView.delegate = self;
    _favoritesRefreshingView.upInset = 0;
    _favoritesRefreshingView.slimeMissWhenGoingBack = YES;
    _favoritesRefreshingView.slime.bodyColor = [UIColor grayColor];
    _favoritesRefreshingView.slime.skinColor = [UIColor grayColor];
    _favoritesRefreshingView.slime.lineWith = 0;
    _favoritesRefreshingView.slime.shadowBlur = 2;
    _favoritesRefreshingView.slime.shadowColor = [UIColor blackColor];
    [_rightTableView addSubview:_favoritesRefreshingView];
    
    [dataHelper helper].homeViewController = self;
    _portraitButton.layer.masksToBounds = YES;
    _orgs = [[NSMutableArray alloc] initWithCapacity:0];
    __weak homeVC *weakSelf = self;
    _balanceSrv = [[qryOrgBankBalanceService alloc] init];
    _balanceSrv.qryOrgBankBalanceBlock = ^(int code, id data){
        [indicatorView dismissOnlyIndicatorAtView:weakSelf.leftTableView];
        if( weakSelf.balanceIsRefreshing ){
            [weakSelf.balanceRefreshingView endRefresh];
            weakSelf.balanceIsRefreshing = NO;
        }
        if( code == 1 ){
            [weakSelf.orgs removeAllObjects];
            NSArray *items = (NSArray*)data;
            for( NSDictionary *item in items ){
                NSString *orgId = [item objectForKey:@"oid"];
                homeOrg *foundOrg;
                for( homeOrg *org in weakSelf.orgs )
                {
                    if( [org.Id isEqualToString:orgId] ){
                        foundOrg = org;
                        break;
                    }
                }
                
                if( !foundOrg ){
                    foundOrg = [[homeOrg alloc] initWithDictionary:item];
                    [weakSelf.orgs addObject:foundOrg];
                }
                [foundOrg add:item];
            }
            [weakSelf updateLeftTableView];
        }
        else{
            if( code == -1202 || code == -1201 ){
                [weakSelf onSessionTimeout];
            }
        }
    };
    
    _favoriteSrv = [[qryMyFavoriteService alloc] init];
    _favoriteSrv.qryMyFavoriteBlock = ^(int code, id data){
        [indicatorView dismissOnlyIndicatorAtView:weakSelf.rightTableView];
        if( weakSelf.favoritesIsRefreshing ){
            [weakSelf.favoritesRefreshingView endRefresh];
            weakSelf.favoritesIsRefreshing = NO;
        }
        if( code == 1 ){
            weakSelf.favoriteAccounts = (NSArray*)data;
            [weakSelf.rightTableView reloadData];
        }
        else{
            ;
        }
    };
    
    _infoSrv = [[getMyInfoService alloc] init];
    _infoSrv.getMyInfoBlock = ^(int code, id data){
        if( code == 1 ){
            NSArray *arr = (NSArray*)data;
            NSDictionary *info = arr.firstObject;
            NSNumber *Id = [info objectForKey:@"id"];
            if( Id ){
                [dataHelper helper].loginUserId = Id.intValue;
            }
            [dataHelper helper].loginUserNo = [info objectForKey:@"userno"];
            [dataHelper helper].userName = [info objectForKey:@"username"];
            NSString *nickName = [info objectForKey:@"name"];
            [dataHelper helper].nickName = nickName;
            [weakSelf.nickNameButton setTitle:nickName forState:UIControlStateNormal];
            CGSize size = [nickName sizeWithFont:weakSelf.nickNameButton.titleLabel.font constrainedToSize:weakSelf.nickNameButton.frame.size];
            CGRect nickNameFrame = weakSelf.nickNameButton.frame;
            nickNameFrame.size = CGSizeMake(size.width+10, size.height);
            weakSelf.nickNameButton.frame = nickNameFrame;
            NSString *user_avatar = [info objectForKey:@"avatar"];
            if( user_avatar ){
                NSData *imageData = [[NSData alloc] initWithBase64EncodedString:user_avatar options:NSDataBase64DecodingIgnoreUnknownCharacters];
                UIImage *image = [UIImage imageWithData:imageData];
                if( image ){
                    [weakSelf.portraitButton setImage:image forState:UIControlStateNormal];
                    [dataHelper helper].portraitImage = image;
                }
            }
        }
        else{
            ;
        }
    };
    
    _qrySystemMsgListSrv = [[qryMsgListService alloc] init];
    _qrySystemMsgListSrv.type = 1;
    _qrySystemMsgListSrv.count = 0;
    _qrySystemMsgListSrv.qryMsgListBlock = ^(int code, id data){
        if( code == 1 ){
            NSArray *msgs = (NSArray*)data;
            MsgObj *msg = msgs.firstObject;
            if( [msg.time isKindOfClass:[NSString class]] && msg.time.length > 0 ){
                NSArray *componets = [msg.time componentsSeparatedByString:@" "];
                NSString *date = componets.firstObject;
                [weakSelf.systemMsgButton setTitle:[NSString stringWithFormat:@"%@ %@", date, msg.title] forState:UIControlStateNormal];
            }
            else{
                [weakSelf.systemMsgButton setTitle:msg.title forState:UIControlStateNormal];
            }
        }
        else{
            ;
        }
    };
    [_qryUserMsgListSrv request];
    [dataHelper helper].qrySystemMsgListSrv = _qrySystemMsgListSrv;
    
    _qryUserMsgListSrv = [[qryMsgListService alloc] init];
    _qryUserMsgListSrv.type = 0;
    _qryUserMsgListSrv.count = 0;
    _qryUserMsgListSrv.qryMsgListBlock = ^(int code, id data){
        ;
    };
    [_qrySystemMsgListSrv request];
    [dataHelper helper].qryUserMsgListSrv = _qryUserMsgListSrv;

    [self loadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy年MM月dd日EEEE";
    _dayInfoLabel.text = [df stringFromDate:[NSDate date]];
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)loadData
{
    [self loadBalance];
    [self loadFavorites];
    [_infoSrv request];
}

- (void)loadBalance
{
    NSDateComponents *components = [Utility currentDateComponents];
    NSString *year = [NSString stringWithFormat:@"%ld", components.year];
    NSString *month = [NSString stringWithFormat:@"%02ld", components.month];
    [indicatorView showOnlyIndicatorAtView:_leftTableView];
    _balanceSrv.year = year;
    _balanceSrv.month = month;
    [_balanceSrv request];
}

- (void)loadFavorites
{
    NSDateComponents *components = [Utility currentDateComponents];
    NSString *year = [NSString stringWithFormat:@"%ld", components.year];
    NSString *month = [NSString stringWithFormat:@"%02ld", components.month];
    [indicatorView showOnlyIndicatorAtView:_rightTableView];
    _favoriteSrv.year = year;
    _favoriteSrv.month = month;
    [_favoriteSrv request];
}

- (void)updateLeftTableView
{
    NSString *prefixTag = @"    ";
    for( homeOrg *org in _orgs ){
        for( homeBank *bank in org.banks ){
            homeItem *rmbItem = [[homeItem alloc] init];
            rmbItem.title = [NSString stringWithFormat:@"%@%@", prefixTag, bank.name];
            rmbItem.value = [NSString stringWithFormat:@"￥%@", [Utility moneyFormatString:bank.rmb]];
            [org.items addObject:rmbItem];
            if( bank.dollar > 0 ){
                homeItem *dollarItem = [[homeItem alloc] init];
                dollarItem.title = rmbItem.title;
                dollarItem.value = [NSString stringWithFormat:@"$%@", [Utility moneyFormatString:bank.dollar]];
                [org.items addObject:dollarItem];
            }
        }
        
        if( org.dollar > 0 ){
            homeItem *orgDollarItem = [[homeItem alloc] init];
            orgDollarItem.title = @"";
            orgDollarItem.value = [NSString stringWithFormat:@"$%@", [Utility moneyFormatString:org.dollar]];
            [org.items insertObject:orgDollarItem atIndex:0];
        }
        homeItem *orgRmbItem = [[homeItem alloc] init];
        orgRmbItem.title = org.name;
        orgRmbItem.value = [NSString stringWithFormat:@"￥%@", [Utility moneyFormatString:org.rmb]];
        [org.items insertObject:orgRmbItem atIndex:0];
    }
    [_leftTableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if( tableView == _leftTableView ){
        return _orgs.count;
    }
    else{
        return 1;
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if( tableView == _leftTableView ){
        homeOrg *org = [_orgs objectAtIndex:section];
        return org.items.count;
    }
    else{
        if( _favoriteAccounts ){
            return _favoriteAccounts.count;
        }
        else{
            return 0;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 20;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 20)];
    view.backgroundColor = [UIColor clearColor];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if( tableView == _leftTableView ){
        return 52;
    }
    else{
        return 80;
    }
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if( tableView == _leftTableView ){
        NSString *Id = @"homeCell";
        homeCell *cell = (homeCell*)[_leftTableView dequeueReusableCellWithIdentifier:Id];
        if( !cell ){
            NSArray *cells = [[NSBundle mainBundle] loadNibNamed:@"cells" owner:nil options:nil];
            cell = [cells objectAtIndex:2];
            cell.backgroundColor = [UIColor clearColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        homeOrg *org = [_orgs objectAtIndex:indexPath.section];
        homeItem *item = [org.items objectAtIndex:indexPath.row];
        cell.titleLabel.text = item.title.length > 0 ? [NSString stringWithFormat:@"%@：", item.title] : @"";
        cell.valueLabel.text = [NSString stringWithFormat:@"%@", item.value];
        if( indexPath.row == 0 || item.title.length == 0 ){
            cell.titleLabel.font = [UIFont fontWithName:@"Microsoft YaHei" size:30];
            cell.valueLabel.font = [UIFont fontWithName:@"Microsoft YaHei" size:30];
        }
        else{
            cell.titleLabel.font = [UIFont fontWithName:@"Microsoft YaHei" size:25];
            cell.valueLabel.font = [UIFont fontWithName:@"Microsoft YaHei" size:25];
            cell.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
        }
        return cell;
    }
    else{
        NSString *Id = @"favoriteCell";
        favoriteCell *cell = (favoriteCell*)[_leftTableView dequeueReusableCellWithIdentifier:Id];
        if( !cell ){
            NSArray *cells = [[NSBundle mainBundle] loadNibNamed:@"cells" owner:nil options:nil];
            cell = [cells objectAtIndex:3];
            cell.backgroundColor = [UIColor clearColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        NSDictionary *info = [_favoriteAccounts objectAtIndex:indexPath.row];
        cell.bankLabel.text = [NSString stringWithFormat:@"%@：", [info objectForKey:@"bank"]];
        cell.accountButton.tag = indexPath.row;
        [cell.accountButton setTitle:[info objectForKey:@"acct"] forState:UIControlStateNormal];
        [cell.accountButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [cell.accountButton addTarget:self action:@selector(onTouchAccount:) forControlEvents:UIControlEventTouchUpInside];
        NSString *amount = [info objectForKey:@"amount"];
        cell.balanceLabel.text = [NSString stringWithFormat:@"%@ %@",[info objectForKey:@"cstr"], [Utility moneyFormatString:amount.floatValue]];
        return cell;
    }
}

- (void)onTouchAccount:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    UIButton *button = (UIButton*)sender;
    NSDictionary *info = [_favoriteAccounts objectAtIndex:button.tag];
    detailVC *vc = [detailVC viewController];
    vc.bank = [info objectForKey:@"bank"];
    vc.company = [info objectForKey:@"org"];
    vc.account = [info objectForKey:@"acct"];
    vc.accountId = [[info objectForKey:@"aid"] intValue];
    vc.currencyType = [info objectForKey:@"ccode"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onTouchSystemMsgButton:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    /*
    if( [dataHelper helper].qrySystemMsgListSrv.msgs.count == 0 ){
        return;
    }
    */
    msgListVC *vc = [msgListVC viewController];
    vc.msgs = _qrySystemMsgListSrv.msgs;
    vc.forSystem = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onTouchSendMsg:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    sendMsgVC *vc = [sendMsgVC viewController];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onTouchReadMsg:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    /*
    if( _qryUserMsgListSrv.msgs.count == 0 )
    {
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"暂时无用户消息！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
        return;
    }
    */
    _badgeLabel.hidden = YES;
    
    msgListVC *vc = [msgListVC viewController];
    vc.msgs = _qryUserMsgListSrv.msgs;
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)onTouchLogout:(id)sender
{
    _logoutAlert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"确定注销当前用户？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定",nil];
    [_logoutAlert show];
}

- (IBAction)onShowUserInfo:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    if( [_pop isPopoverVisible] ){
        [_pop dismissPopoverAnimated:NO];
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    userInfoVC *vc = [storyboard instantiateViewControllerWithIdentifier:@"userInfo"];
    _pop = [[UIPopoverController alloc] initWithContentViewController:vc];
    vc.popover = _pop;
    vc.block = ^(UIImage *portrait, NSString *nickName){
        if( portrait ){
            CGRect portraitFrame = _portraitButton.frame;
            portraitFrame.size = portrait.size;
            [_portraitButton setImage:portrait forState:UIControlStateNormal];
        }
        
        if( nickName ){
            [_nickNameButton setTitle:nickName forState:UIControlStateNormal];
            CGSize size = [nickName sizeWithFont:_nickNameButton.titleLabel.font constrainedToSize:_nickNameButton.frame.size];
            CGRect nickNameFrame = _nickNameButton.frame;
            nickNameFrame.size = CGSizeMake(size.width+10, size.height);
            _nickNameButton.frame = nickNameFrame;
        }
        
    };
    [dataHelper helper].pop = _pop;
    [dataHelper helper].pop.popoverContentSize = CGSizeMake(600, 497);
    [[dataHelper helper].pop presentPopoverFromRect:CGRectMake(self.view.center.x, self.view.center.y, 1, 1) inView:self.view permittedArrowDirections:0 animated:YES];
}

#pragma mark- UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if( _logoutAlert == alertView && 1 == buttonIndex ){
        __weak homeVC *weakSelf = self;
        logoutService *srv = [[logoutService alloc] init];
        srv.logoutBlock = ^(NSInteger code, NSString *data){
            [indicatorView dismissAtView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
            if( [dataHelper helper].loginViewController ){
                [[dataHelper helper].loginViewController prepareLoginAgain];
            }
            [weakSelf.navigationController popToRootViewControllerAnimated:YES];
        };
        [indicatorView showMessage:@"正在注销，请稍候..." atView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
        [srv request];
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView
{
    ;
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
}



#pragma mark - slimeRefresh delegate

- (void)slimeRefreshStartRefresh:(SRRefreshView *)refreshView
{
    if( refreshView == _balanceRefreshingView ){
        _balanceIsRefreshing = YES;
        [self loadBalance];
        [_balanceRefreshingView.activityIndicationView stopAnimating];
    }
    else if( refreshView == _favoritesRefreshingView ){
        _favoritesIsRefreshing = YES;
        [self loadFavorites];
        [_favoritesRefreshingView.activityIndicationView stopAnimating];
    }
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    if( scrollView == _leftTableView ){
        if( !_balanceIsRefreshing ){
            [_balanceRefreshingView scrollViewDidScroll];
        }
    }
    else{
        if( !_favoritesIsRefreshing ){
            [_favoritesRefreshingView scrollViewDidScroll];
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if( scrollView == _leftTableView ){
        if( !_balanceIsRefreshing ){
            [_balanceRefreshingView scrollViewDidEndDraging];
        }
    }
    else{
        if( !_favoritesIsRefreshing ){
            [_favoritesRefreshingView scrollViewDidEndDraging];
        }
    }
}


@end

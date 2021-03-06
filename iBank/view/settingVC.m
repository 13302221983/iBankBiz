//
//  settingVC.m
//  iBank
//
//  Created by McKee on 15/4/18.
//  Copyright (c) 2015年 McKee. All rights reserved.
//

#import "settingVC.h"
#import "dataHelper.h"
#import "logoutService.h"
#import "indicatorView.h"
#import "Utility.h"
#import "aliveHelper.h"
#import "verifyImageService.h"
#import "indicatorView.h"

@implementation serverCell

@end

@implementation loginCell

@end


@interface settingVC ()<UITableViewDataSource,UITableViewDelegate,UIAlertViewDelegate>
{
    IBOutlet UITableView *_tableView;
    logoutService *_logoutService;
    indicatorView *_indicatorView;
    UITextField *_serverTextField;
    UILabel *_timeoutIntervalLabel;
    UISlider *_slider;
    BOOL _useSSL;
    BOOL _autoTimeout;
    BOOL _autoSaveAccount;
    int _timeoutInterval;
}
@property indicatorView *indicatorView;
@property UIAlertView *av;
@end

@implementation settingVC

+ (instancetype)viewController
{
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    settingVC * vc = [storyBoard  instantiateViewControllerWithIdentifier:@"settingVC"];
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if( [dataHelper helper].sessionid.length > 0 ){
        self.navigationController.navigationBarHidden = YES;
    }
    else{
        self.navigationController.navigationBarHidden = NO;
        self.title = @"设置";
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back"] style:UIBarButtonItemStylePlain target:self action:@selector(onTouchBack:)];
    }
    
    _indicatorView = [indicatorView view];
    _indicatorView.label.text = @"正在退出系统，请稍候...";
    __weak settingVC *weakSelf = self;
    _logoutService = [[logoutService alloc] init];
    _logoutService.logoutBlock = ^(NSInteger code, NSString *data){
        [weakSelf.indicatorView dismiss];
        if( [dataHelper helper].loginViewController ){
            [[dataHelper helper].loginViewController prepareLoginAgain];
        }
        [weakSelf.navigationController popToRootViewControllerAnimated:YES];
   };
    
    if( ![dataHelper helper].sessionid ){
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, 64)];
        headerView.backgroundColor = [UIColor clearColor];
        _tableView.tableHeaderView = headerView;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if( [dataHelper helper].sessionid.length > 0 ){
        return 2;
    }
    else{
        return 1;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if( indexPath.row == 0 ){
        return 290;
    }
    else{
        return 345;
    }
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *Id = [NSString stringWithFormat:@"%ld_%ld", indexPath.section, indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Id];
    if( !cell )
    {
        NSArray *cells = [[NSBundle mainBundle] loadNibNamed:@"cells" owner:nil options:nil];
        if( indexPath.row == 0 )
        {
            serverCell *cll = cells.firstObject;
            cll.backgroundColor = [UIColor clearColor];
            [cll.testButton addTarget:self action:@selector(onTouchTest:) forControlEvents:UIControlEventTouchUpInside];
            [cll.sslButton setImage:[UIImage imageNamed:@"灰色-选中"] forState:UIControlStateSelected];
            [cll.sslButton addTarget:self action:@selector(onTouchSSLButton:) forControlEvents:UIControlEventTouchUpInside];
            [cll.saveButton addTarget:self action:@selector(onTouchSave:) forControlEvents:UIControlEventTouchUpInside];
            cll.hostField.text = [dataHelper helper].server;
            cll.sslButton.selected = [dataHelper helper].useSSL;
            if( ![dataHelper helper].sessionid ){
                cll.saveButton.hidden = NO;
            }
            else{
                cll.saveButton.hidden = YES;
            }
            _serverTextField = cll.hostField;
            return cll;
        }
        else{
            loginCell *cll = [cells objectAtIndex:1];
            cll.backgroundColor = [UIColor clearColor];
            if( [dataHelper helper].sessionid.length > 0 ){
                [cll.logoutButton addTarget:self action:@selector(onTouchLogout:) forControlEvents:UIControlEventTouchUpInside];
            }
            else{
                cll.logoutButton.hidden = YES;
            }
            [cll.saveButton addTarget:self action:@selector(onTouchSave:) forControlEvents:UIControlEventTouchUpInside];
            [cll.saveAccountButton setImage:[UIImage imageNamed:@"灰色-选中"] forState:UIControlStateSelected];
            [cll.saveAccountButton addTarget:self action:@selector(onTouchSaveAccountButton:) forControlEvents:UIControlEventTouchUpInside];
            [cll.autoLogoutButton setImage:[UIImage imageNamed:@"灰色-选中"] forState:UIControlStateSelected];
            [cll.autoLogoutButton addTarget:self action:@selector(onTouchAutoLogoutButton:) forControlEvents:UIControlEventTouchUpInside];
            cll.saveAccountButton.selected = [dataHelper helper].autoSaveAccount;
            cll.autoLogoutButton.selected = [dataHelper helper].autoTimeout;
            _timeoutInterval = [dataHelper helper].timeoutInterval;
            _timeoutIntervalLabel = cll.timeoutIntervalLabel;
            _slider = cll.slider;
            [cll.slider addTarget:self action:@selector(onSliderValueChange:) forControlEvents:UIControlEventValueChanged];
            [cll.slider setValue:_timeoutInterval];
            [self updatTimeoutIntervalLabel];
            return cll;
        }
    }
    else{
        return cell;
    }
}

- (void)onTouchLogout:(id)sender
{
    [_indicatorView showAtMainWindow];
    [_logoutService request];
}

- (void)onTouchTest:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    NSString *server = _serverTextField.text;
    if( server.length == 0 ){
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入服务器地址！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
        return;
    }
    
    NSPredicate *ipTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"];
    NSPredicate *hostTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"];
    if( ![ipTest evaluateWithObject:server] && ![hostTest evaluateWithObject:server] ){
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入符合规则的服务器地址！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
        return;
    }
    
    NSString *protocol = @"http";
    NSString *port = [dataHelper helper].port;
    if( _useSSL ){
        protocol = @"https";
        port = [dataHelper helper].sslPort;
    }
    NSString *host = [NSString stringWithFormat:@"%@://%@:%@", protocol, server, port];
    verifyImageService *svr = [[verifyImageService alloc] init];
    svr.url = [NSString stringWithFormat:@"%@/ibankbizdev/index.php/ibankbiz/auth/api?ws=1", host];
    svr.getImageBlock = ^(UIImage *image, NSString *code, NSString *error){
        [indicatorView dismissAtView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
        NSString *tips;
        if( !image ){
            tips = @"未能连接指定服务器，或服务未就绪！";
        }
        else{
            tips = @"服务器可连接，且服务已就绪！";
        }
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"测试结果" message:tips delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
    };
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [indicatorView showMessage:@"正在测试，请稍候..." atView:window.rootViewController.view];
    [svr request];
}

- (void)onTouchSave:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    NSString *server = _serverTextField.text;
    if( server.length == 0 ){
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入服务器地址！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
        return;
    }
    
    NSPredicate *ipTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"];
    NSPredicate *hostTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"];
    if( ![ipTest evaluateWithObject:server] && ![hostTest evaluateWithObject:server] ){
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"请输入符合规则的服务器地址！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
        return;
    }
    
    if( [dataHelper helper].sessionid.length > 0 )
    {
        NSString *server = [dataHelper helper].server.lowercaseString;
        BOOL ssl = [dataHelper helper].useSSL;
        if( ssl != _useSSL || ![server isEqualToString:_serverTextField.text.lowercaseString] )
        {
            _av = [[UIAlertView alloc] initWithTitle:@"确定要保存？" message:@"如果保存，服务器相关设置将会改变，需要重新登录！" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定",nil];
            [_av show];
        }
        else{
            [dataHelper helper].useSSL = _useSSL;
            [dataHelper helper].server = _serverTextField.text;
            [dataHelper helper].autoSaveAccount = _autoSaveAccount;
            [dataHelper helper].autoTimeout = _autoTimeout;
            [dataHelper helper].timeoutInterval = _timeoutInterval;
            [[dataHelper helper] saveSettingToFile];
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"保存设置成功！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [av show];
        }
        
    }
    else{
        [dataHelper helper].useSSL = _useSSL;
        [dataHelper helper].server = _serverTextField.text;
        [dataHelper helper].autoSaveAccount = _autoSaveAccount;
        [dataHelper helper].autoTimeout = _autoTimeout;
        [dataHelper helper].timeoutInterval = _timeoutInterval;
        [[dataHelper helper] saveSettingToFile];
        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"提示" message:@"保存设置成功！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [av show];
    }
}

- (void)onTouchSaveAccountButton:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    UIButton *button = (UIButton*)sender;
    button.selected = !button.selected;
    _autoSaveAccount = button.selected;
}

- (void)onTouchAutoLogoutButton:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    UIButton *button = (UIButton*)sender;
    button.selected = !button.selected;
    _autoTimeout = button.selected;
    if( _autoTimeout ){
        _slider.enabled = YES;
    }
    else{
        _slider.enabled = NO;
    }
}


- (void)onTouchSSLButton:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    UIButton *button = (UIButton*)sender;
    button.selected = !button.selected;
    _useSSL = button.selected;
}

- (void)onTouchBack:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}


- (void)onSliderValueChange:(id)sender
{
    if( ![[dataHelper helper] checkSessionTimeout] )
    {
        return;
    }
    
    UISlider *slider = (UISlider*)sender;
    _timeoutInterval = slider.value;
    [self updatTimeoutIntervalLabel];
}

- (void)updatTimeoutIntervalLabel
{
    if( _timeoutInterval < 5 ) _timeoutInterval = 5;
    NSString *intervalString = [NSString stringWithFormat:@"%d", _timeoutInterval];
    NSString *text = [NSString stringWithFormat:@"%@分钟内无操作自动注销", intervalString];
    NSRange intervalRange = NSMakeRange(0, intervalString.length);
    NSRange textRange = NSMakeRange(0, text.length);
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:text];
    [attrText addAttribute:NSForegroundColorAttributeName value:[Utility colorWithRead:85 green:85 blue:85 alpha:1] range:textRange];
    [attrText addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"MicrosoftYaHei" size:17] range:textRange];
    [attrText addAttribute:NSForegroundColorAttributeName value:[Utility colorWithRead:251 green:122 blue:58 alpha:1] range:intervalRange];
    _timeoutIntervalLabel.attributedText = attrText;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if( alertView == _av && buttonIndex != _av.cancelButtonIndex ){
        [dataHelper helper].useSSL = _useSSL;
        [dataHelper helper].server = _serverTextField.text;
        [dataHelper helper].autoSaveAccount = _autoSaveAccount;
        [dataHelper helper].autoTimeout = _autoTimeout;
        [dataHelper helper].timeoutInterval = _timeoutInterval;
        [[dataHelper helper] saveSettingToFile];
        if( [dataHelper helper].loginViewController ){
            [[dataHelper helper].loginViewController prepareLoginAgain];
        }
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}


@end

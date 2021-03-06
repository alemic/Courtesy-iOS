//
//  CourtesyLoginRegisterViewController.m
//  Courtesy
//
//  Created by Zheng on 2/23/16.
//  Copyright © 2016 82Flex. All rights reserved.
//

//#import "AppDelegate.h"
#import "UMSocial.h"
#import <TencentOpenAPI/TencentOAuth.h>
#import <TencentOpenAPI/TencentApiInterface.h>
#import <TencentOpenAPI/TencentOAuthObject.h>
#import "WeiboUser.h"
#import "CourtesyAccountModel.h"
#import "CourtesyLoginRegisterViewController.h"
#import "CourtesyLoginRegisterTextField.h"
#import "CourtesyLoginRegisterModel.h"

@interface CourtesyLoginRegisterViewController () <CourtesyLoginRegisterDelegate, CourtesyEditProfileDelegate, CourtesyUploadAvatarDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leadingSpace;
@property (weak, nonatomic) IBOutlet CourtesyLoginRegisterTextField *loginEmailTextField;
@property (weak, nonatomic) IBOutlet CourtesyLoginRegisterTextField *loginPasswordTextField;
@property (weak, nonatomic) IBOutlet CourtesyLoginRegisterTextField *registerEmailTextField;
@property (weak, nonatomic) IBOutlet CourtesyLoginRegisterTextField *registerPasswordTextField;
@property (weak, nonatomic) IBOutlet UIButton *authButton;

@property (strong, nonatomic) NSURL *avatarURL;
@property (strong, nonatomic) NSString *openId;
@property (strong, nonatomic) NSString *fakeEmail;

@property (strong, nonatomic) NSDictionary *tencentInfo;
@property (strong, nonatomic) WeiboUser *weiboInfo;
@property (strong, nonatomic) NSDictionary *weixinInfo;

@property (nonatomic, assign) BOOL isRedirected;
@property (nonatomic, weak) NSTimer *countTimer;
@property (nonatomic, assign) NSUInteger seconds;

@end

@implementation CourtesyLoginRegisterViewController

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (UIModalTransitionStyle)modalTransitionStyle {
    return UIModalTransitionStyleFlipHorizontal;
}

#pragma mark - 初始化样式
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// 关闭按钮
- (IBAction)close {
    [self releaseTimer];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 失去焦点
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

// 切换注册登录区域
- (IBAction)loginOrRegister:(UIButton *)button {
    [self.view endEditing:YES];
    if (self.leadingSpace.constant == 0) {
        self.leadingSpace.constant = -self.view.frame.size.width;
        button.selected = YES;
    } else {
        self.leadingSpace.constant = 0;
        button.selected = NO;
    }
    
    [UIView animateWithDuration:0.5 animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - 按钮事件

- (IBAction)loginFromQQ:(id)sender {
    [self.view endEditing:YES];
    [self.view setUserInteractionEnabled:NO];
    [self.view makeToastActivity:CSToastPositionCenter];
    UMSocialSnsPlatform *snsPlatform = [UMSocialSnsPlatformManager getSocialPlatformWithName:UMShareToQQ];
    self.isRedirected = YES;
    snsPlatform.loginClickHandler(self, [UMSocialControllerService defaultControllerService], YES, ^(UMSocialResponseEntity *response) {
        if (response.responseCode == UMSResponseCodeSuccess) {
            self.isRedirected = NO;
            
            UMSocialAccountEntity *snsAccount = [[UMSocialAccountManager socialAccountDictionary] valueForKey:UMShareToQQ];
            CYLog(@"\nusername = %@,\n usid = %@,\n token = %@ iconUrl = %@,\n unionId = %@,\n thirdPlatformUserProfile = %@,\n thirdPlatformResponse = %@ \n, message = %@",
                  snsAccount.userName,
                  snsAccount.usid,
                  snsAccount.accessToken,
                  snsAccount.iconURL,
                  snsAccount.unionId,
                  response.thirdPlatformUserProfile,
                  response.thirdPlatformResponse,
                  response.message);
            
            // 腾讯互联登录成功
            if (
                !response.thirdPlatformResponse ||
                !response.thirdPlatformUserProfile ||
                ![response.thirdPlatformUserProfile isKindOfClass:[NSDictionary class]] ||
                ![response.thirdPlatformResponse isKindOfClass:[TencentOAuth class]] ||
                snsAccount.usid.length <= 0
                ) {
                [self openApiFailed:@"腾讯登录接口通用失败"];
            }
            
            NSString *uniqueStr = [[[snsAccount.usid sha1String] substringToIndex:6] lowercaseString];
            self.openId = [@"qq" stringByAppendingString:uniqueStr];
            self.fakeEmail = [self.openId stringByAppendingString:@"@82flex.com"];
            
            TencentOAuth *tencentAuth = response.thirdPlatformResponse;
            
            kAccount.tencentModel.openId = tencentAuth.openId;
            kAccount.tencentModel.accessToken = tencentAuth.accessToken;
            kAccount.tencentModel.expirationTime = [tencentAuth.expirationDate timeIntervalSince1970];
            
            // 尝试登录
            CourtesyLoginRegisterModel *loginModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:self.fakeEmail password:self.openId delegate:self];
            loginModel.openAPI = CourtesyOpenApiTypeQQ;
            [loginModel sendRequestLogin];
            
            // 设置基本信息
            self.tencentInfo = response.thirdPlatformUserProfile;
        } else {
            [self openApiFailed:response.message];
        }
    });
}

- (IBAction)loginFromWeibo:(id)sender {
    [self.view endEditing:YES];
    [self.view setUserInteractionEnabled:NO];
    [self.view makeToastActivity:CSToastPositionCenter];
    UMSocialSnsPlatform *snsPlatform = [UMSocialSnsPlatformManager getSocialPlatformWithName:UMShareToSina];
    self.isRedirected = YES;
    snsPlatform.loginClickHandler(self, [UMSocialControllerService defaultControllerService], YES, ^(UMSocialResponseEntity *response)
    {
        if (response.responseCode == UMSResponseCodeSuccess) {
            self.isRedirected = NO;
            
            UMSocialAccountEntity *snsAccount = [[UMSocialAccountManager socialAccountDictionary] valueForKey:UMShareToSina];
            CYLog(@"\nusername = %@,\n usid = %@,\n token = %@ iconUrl = %@,\n unionId = %@,\n thirdPlatformUserProfile = %@,\n thirdPlatformResponse = %@ \n, message = %@",
                  snsAccount.userName,
                  snsAccount.usid,
                  snsAccount.accessToken,
                  snsAccount.iconURL,
                  snsAccount.unionId,
                  response.thirdPlatformUserProfile,
                  response.thirdPlatformResponse,
                  response.message);
            
            // 微博互联登录成功
            if (
                !response.thirdPlatformResponse ||
                !response.thirdPlatformUserProfile ||
                ![response.thirdPlatformUserProfile isKindOfClass:[WeiboUser class]] ||
                snsAccount.usid.length <= 0
                ) {
                [self openApiFailed:@"微博登录接口通用失败"];
            }
            
            NSString *uniqueStr = [[[snsAccount.usid sha1String] substringToIndex:6] lowercaseString];
            self.openId = [@"wb" stringByAppendingString:uniqueStr];
            self.fakeEmail = [self.openId stringByAppendingString:@"@82flex.com"];
            
            kAccount.weiboModel.openId = snsAccount.usid;
            kAccount.weiboModel.accessToken = snsAccount.accessToken;
            kAccount.weiboModel.expirationTime = [snsAccount.expirationDate timeIntervalSince1970];
            
            // 尝试登录
            CourtesyLoginRegisterModel *loginModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:self.fakeEmail password:self.openId delegate:self];
            loginModel.openAPI = CourtesyOpenApiTypeWeibo;
            [loginModel sendRequestLogin];
            
            // 设置基本信息
            self.weiboInfo = (WeiboUser *)response.thirdPlatformUserProfile;
        } else {
            [self openApiFailed:response.message];
        }
    });
}

- (IBAction)loginFromWechat:(id)sender {
    [self.view endEditing:YES];
    [self.view setUserInteractionEnabled:NO];
    [self.view makeToastActivity:CSToastPositionCenter];
    UMSocialSnsPlatform *snsPlatform = [UMSocialSnsPlatformManager getSocialPlatformWithName:UMShareToWechatSession];
    self.isRedirected = YES;
    snsPlatform.loginClickHandler(self, [UMSocialControllerService defaultControllerService], YES, ^(UMSocialResponseEntity *response)
    {
        if (response.responseCode == UMSResponseCodeSuccess) {
            self.isRedirected = NO;
            
            UMSocialAccountEntity *snsAccount = [[UMSocialAccountManager socialAccountDictionary] valueForKey:UMShareToWechatSession];
              CYLog(@"\nusername = %@,\n usid = %@,\n token = %@ iconUrl = %@,\n unionId = %@,\n thirdPlatformUserProfile = %@,\n thirdPlatformResponse = %@ \n, message = %@",
                    snsAccount.userName,
                    snsAccount.usid,
                    snsAccount.accessToken,
                    snsAccount.iconURL,
                    snsAccount.unionId,
                    response.thirdPlatformUserProfile,
                    response.thirdPlatformResponse,
                    response.message);
              
            // 微信开放平台登录成功
            if (
                !response.thirdPlatformResponse ||
                !response.thirdPlatformUserProfile ||
                ![response.thirdPlatformUserProfile isKindOfClass:[NSDictionary class]] ||
                snsAccount.usid.length <= 0
                ) {
                [self openApiFailed:@"微信开放平台接口通用失败"];
            }
              
            NSString *uniqueStr = [[[snsAccount.usid sha1String] substringToIndex:6] lowercaseString];
            self.openId = [@"wx" stringByAppendingString:uniqueStr];
            self.fakeEmail = [self.openId stringByAppendingString:@"@82flex.com"];
            
            kAccount.weixinModel.openId = snsAccount.usid;
            kAccount.weixinModel.accessToken = snsAccount.accessToken;
            kAccount.weixinModel.expirationTime = [snsAccount.expirationDate timeIntervalSince1970];
            
            // 尝试登录
            CourtesyLoginRegisterModel *loginModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:self.fakeEmail password:self.openId delegate:self];
            loginModel.openAPI = CourtesyOpenApiTypeWeixin;
            [loginModel sendRequestLogin];
            
            // 设置基本信息
            self.weixinInfo = (NSDictionary *)response.thirdPlatformUserProfile;
        } else {
            [self openApiFailed:response.message];
        }
    });
}

- (IBAction)loginCourtesyAccount:(id)sender {
    [self.view endEditing:YES];
    [self.view setUserInteractionEnabled:NO];
    [self.view makeToastActivity:CSToastPositionCenter];
    CourtesyLoginRegisterModel *loginModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:_loginEmailTextField.text password:_loginPasswordTextField.text delegate:self];
    [loginModel sendRequestLogin];
}

- (IBAction)registerCourtesyAccount:(id)sender {
    [self.view endEditing:YES];
    [self.view setUserInteractionEnabled:NO];
    [self.view makeToastActivity:CSToastPositionCenter];
    CourtesyLoginRegisterModel *regModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:_registerEmailTextField.text password:_registerPasswordTextField.text delegate:self];
    [regModel sendRequestRegister];
}

- (IBAction)forgetPasswordClicked:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:API_FORGET_PASSWORD]];
}

- (IBAction)userAgreementClicked:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:API_TOS]];
}

- (IBAction)getAuthCodeClicked:(UIButton *)sender {
    sender.enabled = NO;
    _seconds = 60;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(timerFireMethod:)
                                                    userInfo:nil
                                                     repeats:YES];
    self.countTimer = timer;
}

- (void)timerFireMethod:(NSTimer *)theTimer {
    if (_seconds == 1) {
        [theTimer invalidate];
        _seconds = 60;
        [_authButton setTitle:@"获取验证码"
                         forState:UIControlStateDisabled];
        [_authButton setEnabled:YES];
    } else {
        _seconds--;
        NSString *title = [NSString stringWithFormat:@"%lus", (unsigned long)_seconds];
        [_authButton setEnabled:NO];
        [_authButton setTitle:title
                         forState:UIControlStateDisabled];
    }
}

- (void)releaseTimer {
    if (_countTimer) {
        if ([_countTimer respondsToSelector:@selector(isValid)]) {
            if ([_countTimer isValid]) {
                [_countTimer invalidate];
                _seconds = 60;
            }
        }
    }
}

#pragma mark - 第三方登录事件通知

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self performSelector:@selector(cancelDetectAction) withObject:nil afterDelay:2.0];
}

- (void)cancelDetectAction {
    if (self.isRedirected) {
        self.isRedirected = NO;
        [self.view setUserInteractionEnabled:YES];
        [self.view hideToastActivity];
    }
}

#pragma mark - CourtesyLoginRegisterDelegate 注册登录委托方法

- (void)loginRegisterFailed:(CourtesyLoginRegisterModel *)sender
               errorMessage:(NSString *)message
                    isLogin:(BOOL)login {
    if (sender.openAPI == CourtesyOpenApiTypeQQ)
    {
        if (login)
        { // 腾讯互联账户登录请求
            CourtesyLoginRegisterModel *registerModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:self.fakeEmail password:self.openId delegate:self];
            registerModel.openAPI = sender.openAPI;
            [registerModel sendRequestRegister];
        }
        else
        {
            [self openApiFailed:message];
        }
    }
    else if (sender.openAPI == CourtesyOpenApiTypeWeibo)
    {
        if (login)
        { // 微博互联账户登录请求
            CourtesyLoginRegisterModel *registerModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:self.fakeEmail password:self.openId delegate:self];
            registerModel.openAPI = sender.openAPI;
            [registerModel sendRequestRegister];
        }
        else
        {
            [self openApiFailed:message];
        }
    }
    else if (sender.openAPI == CourtesyOpenApiTypeWeixin)
    {
        if (login)
        { // 微信开放平台账户登录请求
            CourtesyLoginRegisterModel *registerModel = [[CourtesyLoginRegisterModel alloc] initWithAccount:self.fakeEmail password:self.openId delegate:self];
            registerModel.openAPI = sender.openAPI;
            [registerModel sendRequestRegister];
        }
        else
        {
            [self openApiFailed:message];
        }
    }
    else if (sender.openAPI == CourtesyOpenApiTypeNone)
    {
        [self openApiFailed:message];
    }
}

- (void)loginRegisterSucceed:(CourtesyLoginRegisterModel *)sender
                     isLogin:(BOOL)login {
    [kAccount setEmail:[sender email]]; // 设置账户邮箱
    if (login)
    {
        [self notifyLoginStatus]; // 通知普通登录成功
        [self.view hideToastActivity];
        [self.view makeToast:@"登录成功"
                    duration:kStatusBarNotificationTime
                    position:CSToastPositionCenter
                       title:nil
                       image:nil
                       style:nil
                  completion:^(BOOL didTap) {
                      [self close];
                  }];
    }
    else
    {
        if
            (sender.openAPI == CourtesyOpenApiTypeNone)
        {
            [self notifyLoginStatus]; // 通知普通注册成功
            [self.view hideToastActivity];
            [self.view makeToast:@"注册成功"
                        duration:kStatusBarNotificationTime
                        position:CSToastPositionCenter
                           title:nil
                           image:nil
                           style:nil
                      completion:^(BOOL didTap) {
                          [self close];
                      }];
        }
        else if
            (sender.openAPI == CourtesyOpenApiTypeQQ)
        {
            // 来自腾讯互联的首次注册请求视为第三方登录请求
            if (self.tencentInfo[@"figureurl_qq_2"]) {
                self.avatarURL = [NSURL URLWithString:self.tencentInfo[@"figureurl_qq_2"]];
            }
            
            kProfile.nick = self.tencentInfo[@"nickname"];
            if
                ([self.tencentInfo[@"gender"] isEqualToString:@"男"])
            {
                kProfile.gender = 0;
            }
            else if ([self.tencentInfo[@"gender"] isEqualToString:@"女"])
            {
                kProfile.gender = 1;
            }
            else
            {
                kProfile.gender = 2;
            }
            kProfile.province = self.tencentInfo[@"province"];
            kProfile.city = self.tencentInfo[@"city"];
            kProfile.mobile = @"13800138000";
            kProfile.area = @"";
            kProfile.introduction = @"Tell me why you did it,\nevery dream falling apart.";
            kProfile.birthday = @"1996-01-01";
            kProfile.avatar = @"";
            [kProfile setDelegate:self]; // 设置请求代理
            [kProfile sendRequestEditProfile]; // 发送修改个人资料请求
        }
        else if
            (sender.openAPI == CourtesyOpenApiTypeWeixin)
        {
            if (self.weixinInfo[@"headimgurl"]) {
                self.avatarURL = [NSURL URLWithString:self.weixinInfo[@"headimgurl"]];
            }
            
            kProfile.nick = self.weixinInfo[@"nickname"];
            if
                ([self.weixinInfo[@"sex"] isEqualToNumber:@(1)])
            {
                kProfile.gender = 0;
            }
            else if ([self.weixinInfo[@"sex"] isEqualToNumber:@(2)])
            {
                kProfile.gender = 1;
            }
            else
            {
                kProfile.gender = 2;
            }
            kProfile.province = self.weixinInfo[@"province"];
            kProfile.city = self.weixinInfo[@"city"];
            kProfile.mobile = @"13800138000";
            kProfile.area = @"";
            kProfile.introduction = @"Tell me why you did it,\nevery dream falling apart.";
            kProfile.birthday = @"1996-01-01";
            kProfile.avatar = @"";
            [kProfile setDelegate:self]; // 设置请求代理
            [kProfile sendRequestEditProfile]; // 发送修改个人资料请求
        }
        else if
            (sender.openAPI == CourtesyOpenApiTypeWeibo)
        {
            // 来自微博互联的首次注册请求视为第三方登录请求
            if (self.weiboInfo.avatarHDUrl) {
                self.avatarURL = [NSURL URLWithString:self.weiboInfo.avatarHDUrl]; // 微博高清头像
            }
            kProfile.nick = self.weiboInfo.name;
            
            if
                ([self.weiboInfo.gender isEqualToString:@"m"])
            {
                kProfile.gender = 0;
            }
            else if ([self.weiboInfo.gender isEqualToString:@"w"])
            {
                kProfile.gender = 1;
            }
            else
            {
                kProfile.gender = 2;
            }
            NSArray <NSString *> *locationArr = [self.weiboInfo.location componentsSeparatedByString:@" "];
            if (locationArr.count == 2) {
                kProfile.province = locationArr[0];
                kProfile.city = locationArr[1];
            }
            
            kProfile.mobile = @"13800138000";
            kProfile.area = @"";
            kProfile.introduction = self.weiboInfo.userDescription;
            kProfile.birthday = @"1996-01-01";
            kProfile.avatar = @"";
            [kProfile setDelegate:self]; // 设置请求代理
            [kProfile sendRequestEditProfile]; // 发送修改个人资料请求
        }
    }
}

#pragma mark - 用户提示信息及系统通知

- (void)openApiSucceed
{
    [self notifyLoginStatus];
    [self.view hideToastActivity];
    [self.view makeToast:@"第三方登录成功"
                duration:kStatusBarNotificationTime
                position:CSToastPositionCenter
                   title:nil
                   image:nil
                   style:nil
              completion:^(BOOL didTap) {
                  [self close];
              }];
}

- (void)openApiFailed:(NSString *)errorMessage
{
    [self.view hideToastActivity];
    [self.view setUserInteractionEnabled:YES];
    [self.view makeToast:errorMessage
                duration:kStatusBarNotificationTime
                position:CSToastPositionCenter];
}

- (void)notifyLoginStatus
{
    [sharedSettings setHasLogin:YES];
    // 发送全局登录成功通知
    [NSNotificationCenter sendCTAction:kCourtesyActionLogin message:nil];
}

#pragma mark - 第三方修改资料请求回调

- (void)editProfileSucceed:(CourtesyAccountProfileModel *)sender
{
    NSURL *avatarURL = self.avatarURL;
    
    UIImage *avatarImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:avatarURL]];
    if (avatarImage) {
        [kProfile sendRequestUploadAvatar:avatarImage];
    } else {
        [self openApiSucceed];
    }
}

- (void)editProfileFailed:(CourtesyAccountProfileModel *)sender
             errorMessage:(NSString *)message
{
    [self openApiSucceed];
}

#pragma mark - 第三方上传头像请求回调

- (void)uploadAvatarSucceed:(CourtesyAccountProfileModel *)sender
{
    [self openApiSucceed];
}

- (void)uploadAvatarFailed:(CourtesyAccountProfileModel *)sender
              errorMessage:(NSString *)message
{
    [self openApiSucceed];
}

#pragma mark - Memory Management

- (void)dealloc
{
    CYLog(@"");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

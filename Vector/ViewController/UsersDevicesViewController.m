/*
 Copyright 2017 Vector Creations Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#import "UsersDevicesViewController.h"

#import "AppDelegate.h"
#import "RageShakeManager.h"

#import "VectorDesignValues.h"

#import "EncryptionInfoView.h"

@interface UsersDevicesViewController ()
{
    MXUsersDevicesMap<MXDeviceInfo*> *usersDevices;
    MXSession *mxSession;

    EncryptionInfoView *encryptionInfoView;
}

@end

@implementation UsersDevicesViewController

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.defaultBarTintColor = kVectorNavBarTintColor;
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = NSLocalizedStringFromTable(@"unknown_devices_title", @"Vector", nil);

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDone:)];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    // Register collection view cell class
    [self.tableView registerClass:DeviceTableViewCell.class forCellReuseIdentifier:[DeviceTableViewCell defaultReuseIdentifier]];

    // Hide line separators of empty cells
    self.tableView.tableFooterView = [[UIView alloc] init];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Screen tracking (via Google Analytics)
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    if (tracker)
    {
        [tracker set:kGAIScreenName value:@"UnknowDevices"];
        [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
    }

    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)displayUsersDevices:(MXUsersDevicesMap<MXDeviceInfo*>*)theUsersDevices andMatrixSession:(MXSession*)matrixSession;
{
    usersDevices = theUsersDevices;
    mxSession = matrixSession;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return usersDevices.userIds.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return usersDevices.userIds[section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *userId = usersDevices.userIds[section];
    return [usersDevices deviceIdsForUser:userId].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;

    MXDeviceInfo *device = [self deviceAtIndexPath:indexPath];
    if (device)
    {
        DeviceTableViewCell *deviceCell = [tableView dequeueReusableCellWithIdentifier:[DeviceTableViewCell defaultReuseIdentifier] forIndexPath:indexPath];
        deviceCell.selectionStyle = UITableViewCellSelectionStyleNone;

        [deviceCell render:device];
        deviceCell.delegate = self;

        cell = deviceCell;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MXDeviceInfo *device = [self deviceAtIndexPath:indexPath];

    return [DeviceTableViewCell cellHeightWithDeviceInfo:device andCellWidth:self.tableView.frame.size.width];
}

#pragma mark - DeviceTableViewCellDelegate

- (void)deviceTableViewCell:(DeviceTableViewCell *)deviceTableViewCell updateDeviceVerification:(MXDeviceVerification)verificationStatus
{
    if (verificationStatus == MXDeviceVerified)
    {
        // Prompt the user before marking as verified the device.
        encryptionInfoView = [[EncryptionInfoView alloc] initWithDeviceInfo:deviceTableViewCell.deviceInfo andMatrixSession:mxSession];
        [encryptionInfoView onButtonPressed:encryptionInfoView.verifyButton];

        // Add shadow on added view
        encryptionInfoView.layer.cornerRadius = 5;
        encryptionInfoView.layer.shadowOffset = CGSizeMake(0, 1);
        encryptionInfoView.layer.shadowOpacity = 0.5f;

        // Add the view and define edge constraints
        [self.view addSubview:encryptionInfoView];

        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:encryptionInfoView
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.tableView
                                                              attribute:NSLayoutAttributeTop
                                                             multiplier:1.0f
                                                               constant:10.0f]];

        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:encryptionInfoView
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.tableView
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-10.0f]];

        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView
                                                              attribute:NSLayoutAttributeLeading
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:encryptionInfoView
                                                              attribute:NSLayoutAttributeLeading
                                                             multiplier:1.0f
                                                               constant:-10.0f]];

        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.tableView
                                                              attribute:NSLayoutAttributeTrailing
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:encryptionInfoView
                                                              attribute:NSLayoutAttributeTrailing
                                                             multiplier:1.0f
                                                               constant:10.0f]];
        [self.view setNeedsUpdateConstraints];
    }
    else
    {
        [mxSession.crypto setDeviceVerification:verificationStatus
                                      forDevice:deviceTableViewCell.deviceInfo.deviceId
                                         ofUser:deviceTableViewCell.deviceInfo.userId
                                        success:^{

                                            deviceTableViewCell.deviceInfo.verified = verificationStatus;
                                            [self.tableView reloadData];

                                        } failure:nil];
    }
}

#pragma mark - User actions

- (IBAction)onCancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onDone:(id)sender
{
    // Acknowledge the existence of all devices before leaving this screen
    [mxSession.crypto setDevicesKnown:usersDevices complete:^{
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

#pragma mark - Private methods

- (MXDeviceInfo*)deviceAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *userId = usersDevices.userIds[indexPath.section];
    NSString *deviceId = [usersDevices deviceIdsForUser:userId][indexPath.row];

    return [usersDevices objectForDevice:deviceId forUser:userId];
}

@end

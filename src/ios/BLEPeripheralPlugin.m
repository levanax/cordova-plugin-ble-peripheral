//
//  BLEPeripheralPlugin.m
//  BLE Peripheral Cordova Plugin
//
//  (c) 2106 Don Coleman
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "BLEPeripheralPlugin.h"
#import <Cordova/CDV.h>

static NSDictionary *dataToArrayBuffer(NSData* data) {
    return @{
             @"CDVType" : @"ArrayBuffer",
             @"data" :[data base64EncodedStringWithOptions:0]
             };
}

@interface BLEPeripheralPlugin() {
    NSDictionary *bluetoothStates;
}
@end

@implementation BLEPeripheralPlugin

@synthesize manager;

- (void)pluginInitialize {

    NSLog(@"Cordova BLE Peripheral Plugin");
    NSLog(@"(c)2016 Don Coleman - Updated for iOS 17/18 compatibility");

    [super pluginInitialize];

    // 初始化状态变量
    isAdvertising = NO;
    connectedCentrals = [NSMutableSet new];
    
    // 使用指定队列初始化 CBPeripheralManager，提高性能
    dispatch_queue_t bluetoothQueue = dispatch_queue_create("com.cordova.ble.peripheral", DISPATCH_QUEUE_SERIAL);
    manager = [[CBPeripheralManager alloc] initWithDelegate:self queue:bluetoothQueue options:@{
        CBPeripheralManagerOptionShowPowerAlertKey: @YES,
        CBPeripheralManagerOptionRestoreIdentifierKey: @"CordovaBLEPeripheral"
    }];
    
    services = [NSMutableDictionary new];

    bluetoothStates = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"unknown", @(CBPeripheralManagerStateUnknown),
                       @"resetting", @(CBPeripheralManagerStateResetting),
                       @"unsupported", @(CBPeripheralManagerStateUnsupported),
                       @"unauthorized", @(CBPeripheralManagerStateUnauthorized),
                       @"off", @(CBPeripheralManagerStatePoweredOff),
                       @"on", @(CBPeripheralManagerStatePoweredOn),
                       nil];
}

#pragma mark - Cordova Plugin Methods

- (void)createService:(CDVInvokedUrlCommand *)command {
    NSLog(@"createService called with arguments: %@", command.arguments);
    
    if ([command.arguments count] < 1) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Missing service UUID parameter"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *uuidString = [command.arguments objectAtIndex:0];
    CBUUID *serviceUUID = [CBUUID UUIDWithString: uuidString];
    
    if (!serviceUUID) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Invalid service UUID"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
    [services setObject:service forKey:uuidString];
    
    NSLog(@"Service created successfully: %@", uuidString);
    
    // 返回包含设备信息的成功响应
    NSMutableDictionary *result = [NSMutableDictionary new];
    [result setObject:@"success" forKey:@"status"];
    [result setObject:uuidString forKey:@"serviceUUID"];
    [result setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
    
    // 添加设备基本信息
    UIDevice *device = [UIDevice currentDevice];
    [result setObject:[device name] forKey:@"deviceName"];
    [result setObject:[[device identifierForVendor] UUIDString] forKey:@"deviceIdentifier"];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                   messageAsDictionary:result];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)addCharacteristic:(CDVInvokedUrlCommand *)command {
    NSLog(@"addCharacteristic called with arguments: %@", command.arguments);
    
    if ([command.arguments count] < 4) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Missing required parameters"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    CBMutableService *service = [services objectForKey:serviceUUIDString];

    if (service) {
        NSString *characteristicUUIDString = [command.arguments objectAtIndex:1];
        CBUUID *characteristicUUID = [CBUUID UUIDWithString: characteristicUUIDString];
        
        if (!characteristicUUID) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                              messageAsString:@"Invalid characteristic UUID"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        NSNumber *properties = [command.arguments objectAtIndex:2];
        NSNumber *permissions = [command.arguments objectAtIndex:3];

        CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc]
                                                   initWithType:characteristicUUID
                                                   properties: properties.intValue & 0xff
                                                   value:nil
                                                   permissions: permissions.intValue & 0xff];

        // appending characteristic to existing list
        NSMutableArray *characteristics = [NSMutableArray arrayWithArray:[service characteristics]];
        [characteristics addObject:characteristic];
        service.characteristics = characteristics;

        NSLog(@"Characteristic added successfully: %@ to service: %@", characteristicUUIDString, serviceUUIDString);
        
        // 返回包含特征信息的成功响应
        NSMutableDictionary *result = [NSMutableDictionary new];
        [result setObject:@"success" forKey:@"status"];
        [result setObject:serviceUUIDString forKey:@"serviceUUID"];
        [result setObject:characteristicUUIDString forKey:@"characteristicUUID"];
        [result setObject:properties forKey:@"properties"];
        [result setObject:permissions forKey:@"permissions"];
        [result setObject:@([service.characteristics count]) forKey:@"totalCharacteristics"];
        [result setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                       messageAsDictionary:result];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    } else {
        NSString *message = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
        NSLog(@"Error: %@", message);
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

// note: need to call this after the characteristics are added
- (void)publishService:(CDVInvokedUrlCommand *)command {
    NSLog(@"%@", @"publishService");
    
    // 检查蓝牙状态
    if (manager.state != CBPeripheralManagerStatePoweredOn) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Bluetooth is not powered on"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    CBMutableService *service = [services objectForKey:serviceUUIDString];
    
    if (!service) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Service not found"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    publishServiceCallbackId = [command.callbackId copy];
    [manager addService:service];
}

- (void)setCharacteristicValue:(CDVInvokedUrlCommand *)command {
    NSLog(@"%@", @"setCharacteristicValue");
    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    CBMutableService *service = [services objectForKey:serviceUUIDString];

    NSString *characteristicUUIDString = [command.arguments objectAtIndex:1];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];

    NSData *data = [command.arguments objectAtIndex:2];

    if (service) {
        CBMutableCharacteristic *characteristic  = (CBMutableCharacteristic*)[self findCharacteristicByUUID: characteristicUUID service:service];

        [characteristic setValue:data];

        // if notify && value has changed
        [manager updateValue:data forCharacteristic:characteristic onSubscribedCentrals:nil];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    } else {
        NSString *message = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

}

- (void)createServiceFromJSON:(CDVInvokedUrlCommand *)command {
    NSLog(@"%@", @"addServiceFromJSON");

    createServiceFromJSONCallbackId = [command.callbackId copy];

    // This might be a problem when the data contains nested ArrayBuffers
    NSDictionary *dictionary = [command.arguments objectAtIndex:0];
    CBMutableService *service = [self serviceFromJSON: dictionary];
    [manager addService:service];
}

- (void)startAdvertising:(CDVInvokedUrlCommand *)command {
    
    // 检查蓝牙状态
    if (manager.state != CBPeripheralManagerStatePoweredOn) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Bluetooth is not powered on"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 检查参数
    if ([command.arguments count] < 2) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Missing required parameters"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    NSString *localName = [command.arguments objectAtIndex:1];
    
    // 验证UUID格式
    CBUUID *serviceUUID = [CBUUID UUIDWithString: serviceUUIDString];
    if (!serviceUUID) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Invalid service UUID"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 停止之前的广播
    if (isAdvertising) {
        [manager stopAdvertising];
    }

    // 构建广播数据
    NSMutableDictionary *advertisementData = [NSMutableDictionary new];
    [advertisementData setObject:@[serviceUUID] forKey:CBAdvertisementDataServiceUUIDsKey];
    
    if (localName && [localName length] > 0) {
        // iOS限制本地名称长度
        if ([localName length] > 28) {
            localName = [localName substringToIndex:28];
        }
        [advertisementData setObject:localName forKey:CBAdvertisementDataLocalNameKey];
    }

    [manager startAdvertising:advertisementData];
    startAdvertisingCallbackId = [command.callbackId copy];
}

- (void)setCharacteristicValueChangedListener:(CDVInvokedUrlCommand *)command {
    characteristicValueChangedCallback = [command.callbackId copy];
}

- (void)setDescriptorValueChangedListener:(CDVInvokedUrlCommand *)command {
    descriptorValueChangedCallback  = [command.callbackId copy];
}

- (void)setBluetoothStateChangedListener:(CDVInvokedUrlCommand *)command {
    NSLog(@"🔔 setBluetoothStateChangedListener called, callbackId: %@", command.callbackId);
    bluetoothStateChangedCallback  = [command.callbackId copy];
    NSLog(@"✅ bluetoothStateChangedCallback set to: %@", bluetoothStateChangedCallback);

    int bluetoothState = [manager state];
    NSString *state = [bluetoothStates objectForKey:[NSNumber numberWithInt:bluetoothState]];
    NSLog(@"📡 Current Bluetooth state: %@ (%d)", state, bluetoothState);
    
    CDVPluginResult *pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:state];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    NSLog(@"✅ Initial state sent to JavaScript: %@", state);
}

// 新增方法实现
- (void)stopAdvertising:(CDVInvokedUrlCommand *)command {
    [manager stopAdvertising];
    isAdvertising = NO;
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isAdvertising:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                       messageAsBool:isAdvertising];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getConnectedCentrals:(CDVInvokedUrlCommand *)command {
    NSMutableArray *centralArray = [NSMutableArray new];
    for (CBCentral *central in connectedCentrals) {
        [centralArray addObject:@{
            @"identifier": [central.identifier UUIDString],
            @"maximumUpdateValueLength": @(central.maximumUpdateValueLength)
        }];
    }
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                       messageAsArray:centralArray];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)removeService:(CDVInvokedUrlCommand *)command {
    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    CBMutableService *service = [services objectForKey:serviceUUIDString];
    
    if (service) {
        [manager removeService:service];
        [services removeObjectForKey:serviceUUIDString];
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
        NSString *message = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)removeAllServices:(CDVInvokedUrlCommand *)command {
    [manager removeAllServices];
    [services removeAllObjects];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// 通知指定特征值给连接的中心设备
- (void)notifyCharacteristicValue:(CDVInvokedUrlCommand *)command {
    NSLog(@"notifyCharacteristicValue");
    
    // 检查参数数量
    if ([command.arguments count] < 3) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Missing required parameters: serviceUUID, characteristicUUID, value"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    NSString *characteristicUUIDString = [command.arguments objectAtIndex:1];
    NSData *data = [command.arguments objectAtIndex:2];
    
    // 可选参数：指定中心设备
    NSArray *centralIdentifiers = nil;
    if ([command.arguments count] > 3) {
        centralIdentifiers = [command.arguments objectAtIndex:3];
    }
    
    // 查找服务
    CBMutableService *service = [services objectForKey:serviceUUIDString];
    if (!service) {
        NSString *message = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 查找特征
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
    CBMutableCharacteristic *characteristic = (CBMutableCharacteristic*)[self findCharacteristicByUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        NSString *message = [NSString stringWithFormat:@"Characteristic not found for UUID %@", characteristicUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 检查特征是否支持通知
    if (!(characteristic.properties & CBCharacteristicPropertyNotify) && 
        !(characteristic.properties & CBCharacteristicPropertyIndicate)) {
        NSString *message = [NSString stringWithFormat:@"Characteristic %@ does not support notifications or indications", characteristicUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 准备目标中心设备列表
    NSArray *targetCentrals = nil;
    if (centralIdentifiers && [centralIdentifiers count] > 0) {
        NSMutableArray *centrals = [NSMutableArray new];
        for (NSString *identifier in centralIdentifiers) {
            for (CBCentral *central in connectedCentrals) {
                if ([[central.identifier UUIDString] isEqualToString:identifier]) {
                    [centrals addObject:central];
                    break;
                }
            }
        }
        targetCentrals = centrals;
    }
    
    // 更新特征值
    [characteristic setValue:data];
    
    // 发送通知
    BOOL success = [manager updateValue:data 
                         forCharacteristic:characteristic 
                      onSubscribedCentrals:targetCentrals];
    
    CDVPluginResult *pluginResult = nil;
    if (success) {
        NSMutableDictionary *result = [NSMutableDictionary new];
        [result setObject:@"success" forKey:@"status"];
        [result setObject:serviceUUIDString forKey:@"service"];
        [result setObject:characteristicUUIDString forKey:@"characteristic"];
        [result setObject:@([data length]) forKey:@"dataLength"];
        
        if (targetCentrals) {
            [result setObject:@([targetCentrals count]) forKey:@"targetCentralsCount"];
        } else {
            [result setObject:@([connectedCentrals count]) forKey:@"targetCentralsCount"];
        }
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                       messageAsDictionary:result];
    } else {
        NSMutableDictionary *errorResult = [NSMutableDictionary new];
        [errorResult setObject:@"failed" forKey:@"status"];
        [errorResult setObject:@"Failed to send notification. This can happen if the transmission queue is full or no centrals are subscribed." forKey:@"message"];
        [errorResult setObject:serviceUUIDString forKey:@"service"];
        [errorResult setObject:characteristicUUIDString forKey:@"characteristic"];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                       messageAsDictionary:errorResult];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// 向所有连接的中心设备发送通知（广播消息）
- (void)notifyAllCentrals:(CDVInvokedUrlCommand *)command {
    NSLog(@"notifyAllCentrals");
    
    // 检查参数
    if ([command.arguments count] < 3) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"Missing required parameters: serviceUUID, characteristicUUID, value"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    NSString *serviceUUIDString = [command.arguments objectAtIndex:0];
    NSString *characteristicUUIDString = [command.arguments objectAtIndex:1];
    NSData *data = [command.arguments objectAtIndex:2];
    
    // 检查是否有连接的设备
    if ([connectedCentrals count] == 0) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"No connected central devices"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 查找服务和特征
    CBMutableService *service = [services objectForKey:serviceUUIDString];
    if (!service) {
        NSString *message = [NSString stringWithFormat:@"Service not found for UUID %@", serviceUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDString];
    CBMutableCharacteristic *characteristic = (CBMutableCharacteristic*)[self findCharacteristicByUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        NSString *message = [NSString stringWithFormat:@"Characteristic not found for UUID %@", characteristicUUIDString];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    // 更新特征值并发送通知给所有订阅的设备
    [characteristic setValue:data];
    BOOL success = [manager updateValue:data 
                         forCharacteristic:characteristic 
                      onSubscribedCentrals:nil]; // nil 表示发送给所有订阅的设备
    
    CDVPluginResult *pluginResult = nil;
    if (success) {
        NSMutableDictionary *result = [NSMutableDictionary new];
        [result setObject:@"success" forKey:@"status"];
        [result setObject:serviceUUIDString forKey:@"service"];
        [result setObject:characteristicUUIDString forKey:@"characteristic"];
        [result setObject:@([data length]) forKey:@"dataLength"];
        [result setObject:@([connectedCentrals count]) forKey:@"connectedCentralsCount"];
        [result setObject:@"Notification sent to all subscribed centrals" forKey:@"message"];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                       messageAsDictionary:result];
    } else {
        NSMutableDictionary *errorResult = [NSMutableDictionary new];
        [errorResult setObject:@"failed" forKey:@"status"];
        [errorResult setObject:@"Failed to send notification to all centrals. This can happen if the transmission queue is full or no centrals are subscribed." forKey:@"message"];
        [errorResult setObject:serviceUUIDString forKey:@"service"];
        [errorResult setObject:characteristicUUIDString forKey:@"characteristic"];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                       messageAsDictionary:errorResult];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// 调试和状态检查方法
- (void)getBluetoothState:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *stateInfo = [NSMutableDictionary new];
    
    NSString *state = [bluetoothStates objectForKey:@(manager.state)];
    [stateInfo setObject:state forKey:@"state"];
    [stateInfo setObject:@(manager.state) forKey:@"stateCode"];
    
    if (@available(iOS 13.1, *)) {
        CBManagerAuthorization authorization = [CBManager authorization];
        [stateInfo setObject:@(authorization) forKey:@"authorization"];
        
        NSString *authString = @"unknown";
        switch (authorization) {
            case CBManagerAuthorizationNotDetermined:
                authString = @"notDetermined";
                break;
            case CBManagerAuthorizationRestricted:
                authString = @"restricted";
                break;
            case CBManagerAuthorizationDenied:
                authString = @"denied";
                break;
            case CBManagerAuthorizationAllowedAlways:
                authString = @"allowedAlways";
                break;
        }
        [stateInfo setObject:authString forKey:@"authorizationString"];
    }
    
    [stateInfo setObject:@(isAdvertising) forKey:@"isAdvertising"];
    [stateInfo setObject:@([connectedCentrals count]) forKey:@"connectedCentralsCount"];
    [stateInfo setObject:@([services count]) forKey:@"servicesCount"];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                   messageAsDictionary:stateInfo];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getManagerInfo:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *managerInfo = [NSMutableDictionary new];
    
    [managerInfo setObject:@(manager != nil) forKey:@"managerExists"];
    if (manager) {
        [managerInfo setObject:@(manager.state) forKey:@"state"];
        [managerInfo setObject:[bluetoothStates objectForKey:@(manager.state)] forKey:@"stateString"];
    }
    
    // iOS版本信息
    [managerInfo setObject:[[UIDevice currentDevice] systemVersion] forKey:@"iOSVersion"];
    
    // 服务信息
    NSMutableArray *serviceInfos = [NSMutableArray new];
    for (NSString *serviceUUID in [services allKeys]) {
        CBMutableService *service = [services objectForKey:serviceUUID];
        NSMutableDictionary *serviceInfo = [NSMutableDictionary new];
        [serviceInfo setObject:serviceUUID forKey:@"uuid"];
        [serviceInfo setObject:@([service.characteristics count]) forKey:@"characteristicsCount"];
        [serviceInfos addObject:serviceInfo];
    }
    [managerInfo setObject:serviceInfos forKey:@"services"];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                   messageAsDictionary:managerInfo];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// 获取外设信息（包括蓝牙地址等）
- (void)getPeripheralInfo:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *peripheralInfo = [NSMutableDictionary new];
    
    // 设备基本信息
    UIDevice *device = [UIDevice currentDevice];
    [peripheralInfo setObject:[device name] forKey:@"deviceName"];
    [peripheralInfo setObject:[device model] forKey:@"deviceModel"];
    [peripheralInfo setObject:[device systemName] forKey:@"systemName"];
    [peripheralInfo setObject:[device systemVersion] forKey:@"systemVersion"];
    
    // 设备标识符（iOS不允许直接获取蓝牙MAC地址，使用设备标识符代替）
    [peripheralInfo setObject:[[device identifierForVendor] UUIDString] forKey:@"deviceIdentifier"];
    
    // 蓝牙管理器信息
    if (manager) {
        [peripheralInfo setObject:@(manager.state) forKey:@"bluetoothState"];
        [peripheralInfo setObject:[bluetoothStates objectForKey:@(manager.state)] forKey:@"bluetoothStateString"];
        [peripheralInfo setObject:@(isAdvertising) forKey:@"isAdvertising"];
        
        // iOS 13+ 权限信息
        if (@available(iOS 13.1, *)) {
            CBManagerAuthorization authorization = [CBManager authorization];
            [peripheralInfo setObject:@(authorization) forKey:@"bluetoothAuthorization"];
            
            NSString *authString = @"unknown";
            switch (authorization) {
                case CBManagerAuthorizationNotDetermined:
                    authString = @"notDetermined";
                    break;
                case CBManagerAuthorizationRestricted:
                    authString = @"restricted";
                    break;
                case CBManagerAuthorizationDenied:
                    authString = @"denied";
                    break;
                case CBManagerAuthorizationAllowedAlways:
                    authString = @"allowedAlways";
                    break;
            }
            [peripheralInfo setObject:authString forKey:@"bluetoothAuthorizationString"];
        }
    }
    
    // 服务信息
    NSMutableArray *serviceInfos = [NSMutableArray new];
    for (NSString *serviceUUID in [services allKeys]) {
        CBMutableService *service = [services objectForKey:serviceUUID];
        NSMutableDictionary *serviceInfo = [NSMutableDictionary new];
        [serviceInfo setObject:serviceUUID forKey:@"uuid"];
        [serviceInfo setObject:@([service.characteristics count]) forKey:@"characteristicsCount"];
        [serviceInfo setObject:@(service.isPrimary) forKey:@"isPrimary"];
        
        // 特征信息
        NSMutableArray *characteristicInfos = [NSMutableArray new];
        for (CBMutableCharacteristic *characteristic in service.characteristics) {
            NSMutableDictionary *charInfo = [NSMutableDictionary new];
            [charInfo setObject:[[characteristic UUID] UUIDString] forKey:@"uuid"];
            [charInfo setObject:@(characteristic.properties) forKey:@"properties"];
            [charInfo setObject:@(characteristic.permissions) forKey:@"permissions"];
            [charInfo setObject:@([characteristic.descriptors count]) forKey:@"descriptorsCount"];
            [characteristicInfos addObject:charInfo];
        }
        [serviceInfo setObject:characteristicInfos forKey:@"characteristics"];
        
        [serviceInfos addObject:serviceInfo];
    }
    [peripheralInfo setObject:serviceInfos forKey:@"services"];
    
    // 连接的中心设备信息
    NSMutableArray *centralInfos = [NSMutableArray new];
    for (CBCentral *central in connectedCentrals) {
        NSMutableDictionary *centralInfo = [NSMutableDictionary new];
        [centralInfo setObject:[central.identifier UUIDString] forKey:@"identifier"];
        [centralInfo setObject:@(central.maximumUpdateValueLength) forKey:@"maximumUpdateValueLength"];
        [centralInfos addObject:centralInfo];
    }
    [peripheralInfo setObject:centralInfos forKey:@"connectedCentrals"];
    
    // 时间戳
    [peripheralInfo setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                   messageAsDictionary:peripheralInfo];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// 获取本地蓝牙信息（更详细的蓝牙相关信息）
- (void)getLocalBluetoothInfo:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *bluetoothInfo = [NSMutableDictionary new];
    
    if (manager) {
        // 基本状态信息
        [bluetoothInfo setObject:@(manager.state) forKey:@"state"];
        [bluetoothInfo setObject:[bluetoothStates objectForKey:@(manager.state)] forKey:@"stateString"];
        [bluetoothInfo setObject:@(isAdvertising) forKey:@"isAdvertising"];
        
        // 权限信息
        if (@available(iOS 13.1, *)) {
            CBManagerAuthorization authorization = [CBManager authorization];
            [bluetoothInfo setObject:@(authorization) forKey:@"authorization"];
            
            NSArray *authDescriptions = @[@"notDetermined", @"restricted", @"denied", @"allowedAlways"];
            if (authorization < [authDescriptions count]) {
                [bluetoothInfo setObject:authDescriptions[authorization] forKey:@"authorizationString"];
            }
        }
        
        // 广播能力检查
        if (manager.state == CBPeripheralManagerStatePoweredOn) {
            // 检查是否支持广播
            [bluetoothInfo setObject:@YES forKey:@"supportsAdvertising"];
            
            // 获取最大广播数据长度（iOS 10+）
            if (@available(iOS 10.0, *)) {
                // 注意：这个方法在某些情况下可能不可用
                @try {
                    // iOS没有直接的API获取最大广播长度，使用经验值
                    [bluetoothInfo setObject:@(31) forKey:@"maxAdvertisingDataLength"]; // iOS标准BLE广播数据长度
                } @catch (NSException *exception) {
                    [bluetoothInfo setObject:@(-1) forKey:@"maxAdvertisingDataLength"];
                }
            }
        } else {
            [bluetoothInfo setObject:@NO forKey:@"supportsAdvertising"];
        }
        
        // 设备角色信息
        [bluetoothInfo setObject:@"peripheral" forKey:@"role"];
        [bluetoothInfo setObject:@([services count]) forKey:@"publishedServicesCount"];
        [bluetoothInfo setObject:@([connectedCentrals count]) forKey:@"connectedCentralsCount"];
        
        // 生成一个会话标识符（用于区分不同的蓝牙会话）
        static NSString *sessionId = nil;
        if (!sessionId) {
            sessionId = [[NSUUID UUID] UUIDString];
        }
        [bluetoothInfo setObject:sessionId forKey:@"sessionId"];
        
    } else {
        [bluetoothInfo setObject:@"manager_not_initialized" forKey:@"error"];
    }
    
    // 系统信息
    [bluetoothInfo setObject:[[UIDevice currentDevice] systemVersion] forKey:@"iOSVersion"];
    [bluetoothInfo setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                   messageAsDictionary:bluetoothInfo];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - CBPeripheralManagerDelegate


- (void) peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {

    NSLog(@"Added a service");
    if (error) {
        NSLog(@"There was an error adding service");
        NSLog(@"%@", error);
    }

    // 确保在主线程中处理回调
    dispatch_async(dispatch_get_main_queue(), ^{
        if (publishServiceCallbackId) {
            CDVPluginResult *pluginResult = nil;

            if (!error) {
                // 返回包含服务发布信息的成功响应
                NSMutableDictionary *result = [NSMutableDictionary new];
                [result setObject:@"success" forKey:@"status"];
                [result setObject:[[service UUID] UUIDString] forKey:@"serviceUUID"];
                [result setObject:@([service.characteristics count]) forKey:@"characteristicsCount"];
                [result setObject:@(service.isPrimary) forKey:@"isPrimary"];
                [result setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
                
                // 添加设备信息
                UIDevice *device = [UIDevice currentDevice];
                [result setObject:[device name] forKey:@"deviceName"];
                [result setObject:[[device identifierForVendor] UUIDString] forKey:@"deviceIdentifier"];
                
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                               messageAsDictionary:result];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:publishServiceCallbackId];

            publishServiceCallbackId = nil;
        }

        // essentially the same as above
        if (createServiceFromJSONCallbackId) {
            CDVPluginResult *pluginResult = nil;

            if (!error) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:createServiceFromJSONCallbackId];

            createServiceFromJSONCallbackId = nil;
        }
    });
}

- (void) peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    NSLog(@"Started advertising");
    if (error) {
        NSLog(@"There was an error advertising: %@", error);
        isAdvertising = NO;
    } else {
        isAdvertising = YES;
    }

    // 确保在主线程中处理回调
    dispatch_async(dispatch_get_main_queue(), ^{
        if (startAdvertisingCallbackId) {
            CDVPluginResult *pluginResult = nil;

            if (!error) {
                // 返回包含广播信息和设备信息的成功响应
                NSMutableDictionary *result = [NSMutableDictionary new];
                [result setObject:@"success" forKey:@"status"];
                [result setObject:@"advertising_started" forKey:@"message"];
                [result setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"timestamp"];
                
                // 设备信息
                UIDevice *device = [UIDevice currentDevice];
                [result setObject:[device name] forKey:@"deviceName"];
                [result setObject:[device model] forKey:@"deviceModel"];
                [result setObject:[[device identifierForVendor] UUIDString] forKey:@"deviceIdentifier"];
                [result setObject:[device systemVersion] forKey:@"iOSVersion"];
                
                // 蓝牙信息
                [result setObject:@(manager.state) forKey:@"bluetoothState"];
                [result setObject:[bluetoothStates objectForKey:@(manager.state)] forKey:@"bluetoothStateString"];
                [result setObject:@(isAdvertising) forKey:@"isAdvertising"];
                [result setObject:@([services count]) forKey:@"publishedServicesCount"];
                
                // 权限信息（iOS 13+）
                if (@available(iOS 13.1, *)) {
                    CBManagerAuthorization authorization = [CBManager authorization];
                    [result setObject:@(authorization) forKey:@"bluetoothAuthorization"];
                    
                    NSArray *authStrings = @[@"notDetermined", @"restricted", @"denied", @"allowedAlways"];
                    if (authorization < [authStrings count]) {
                        [result setObject:authStrings[authorization] forKey:@"bluetoothAuthorizationString"];
                    }
                }
                
                // 生成广播会话ID
                NSString *advertisingSessionId = [[NSUUID UUID] UUIDString];
                [result setObject:advertisingSessionId forKey:@"advertisingSessionId"];
                
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                               messageAsDictionary:result];
            } else {
                NSMutableDictionary *errorDict = [NSMutableDictionary new];
                [errorDict setObject:[error localizedDescription] forKey:@"message"];
                [errorDict setObject:@([error code]) forKey:@"code"];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                               messageAsDictionary:errorDict];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:startAdvertisingCallbackId];

            startAdvertisingCallbackId = nil;
        }
    });
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic: %@ from device: %@", [[characteristic UUID] UUIDString], [central.identifier UUIDString]);
    
    // 检测新连接：如果这是第一次收到来自该设备的订阅，发送连接通知
    BOOL isNewConnection = NO;
    if (![connectedCentrals containsObject:central]) {
        isNewConnection = YES;
        [connectedCentrals addObject:central];
        NSLog(@"New central connected (via subscription): %@", [central.identifier UUIDString]);
    }
    
    // 如果是新连接，发送连接通知
    // iOS 18 要求回调必须在主线程中执行
    if (isNewConnection) {
        NSLog(@"📤 Preparing to send connection notification (subscription)");
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"📤 On main thread, checking callback: %@", self->bluetoothStateChangedCallback);
            if (self->bluetoothStateChangedCallback) {
                NSDictionary *connectionInfo = @{
                    @"type": @"connection",
                    @"state": @"connected",
                    @"device": [central.identifier UUIDString],
                    @"characteristic": [[characteristic UUID] UUIDString],
                    @"service": [[[characteristic service] UUID] UUIDString]
                };
                
                NSLog(@"📤 Creating plugin result with connection info: %@", connectionInfo);
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                               messageAsDictionary:connectionInfo];
                [pluginResult setKeepCallbackAsBool:TRUE];
                
                NSLog(@"📤 Sending plugin result to JavaScript, callbackId: %@", self->bluetoothStateChangedCallback);
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self->bluetoothStateChangedCallback];
                NSLog(@"✅ Connection notification sent successfully (subscription)");
            } else {
                NSLog(@"⚠️ bluetoothStateChangedCallback is nil in didSubscribeToCharacteristic");
            }
        });
    }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    NSLog(@"Received %lu write requests", (unsigned long)[requests count]);

    for (CBATTRequest *request in requests) {
        CBCharacteristic *characteristic = [request characteristic];
        CBCentral *central = [request central];
        
        // 检测新连接：如果这是第一次收到来自该设备的请求，发送连接通知
        BOOL isNewConnection = NO;
        if (central) {
            if (![connectedCentrals containsObject:central]) {
                isNewConnection = YES;
                [connectedCentrals addObject:central];
                NSLog(@"✅ New central connected (via write request): %@, total connected: %lu", 
                      [central.identifier UUIDString], (unsigned long)[connectedCentrals count]);
                
                // 发送连接通知
                if (bluetoothStateChangedCallback) {
                    NSDictionary *connectionInfo = @{
                        @"type": @"connection",
                        @"state": @"connected",
                        @"device": [central.identifier UUIDString],
                        @"characteristic": [[characteristic UUID] UUIDString],
                        @"service": [[[characteristic service] UUID] UUIDString]
                    };
                    
                    NSLog(@"📤 Sending connection notification to JavaScript");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (self->bluetoothStateChangedCallback) {
                            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                                       messageAsDictionary:connectionInfo];
                            [pluginResult setKeepCallbackAsBool:TRUE];
                            [self.commandDelegate sendPluginResult:pluginResult callbackId:self->bluetoothStateChangedCallback];
                            NSLog(@"✅ Connection notification sent successfully");
                        } else {
                            NSLog(@"⚠️ bluetoothStateChangedCallback is nil, cannot send connection notification");
                        }
                    });
                } else {
                    NSLog(@"⚠️ bluetoothStateChangedCallback is nil, cannot send connection notification");
                }
            } else {
                NSLog(@"📝 Write request from known central: %@", [central.identifier UUIDString]);
            }
        } else {
            NSLog(@"⚠️ Write request has no central information");
        }

        NSMutableDictionary *dictionary = [NSMutableDictionary new];
        [dictionary setObject:[[[characteristic service] UUID] UUIDString] forKey:@"service"];
        [dictionary setObject:[[characteristic UUID] UUIDString] forKey:@"characteristic"];
        if ([request value]) {
            [dictionary setObject:dataToArrayBuffer([request value]) forKey:@"value"];
        }

        // 先响应请求，避免超时
        [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
        
        // iOS 18 要求回调必须在主线程中执行
        if (characteristicValueChangedCallback) {
            NSDictionary *callbackDict = [dictionary copy]; // 复制字典以避免线程问题
            dispatch_async(dispatch_get_main_queue(), ^{
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:callbackDict];
                [pluginResult setKeepCallbackAsBool:TRUE];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:self->characteristicValueChangedCallback];
            });
        }
    }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    NSLog(@"Received read request for %@", [request characteristic]);

    CBCharacteristic *requestedCharacteristic = request.characteristic;
    CBService *requestedService = [requestedCharacteristic service];
    CBCentral *central = [request central];
    
    // 检测新连接：如果这是第一次收到来自该设备的请求，发送连接通知
    if (central) {
        if (![connectedCentrals containsObject:central]) {
            [connectedCentrals addObject:central];
            NSLog(@"✅ New central connected (via read request): %@, total connected: %lu", 
                  [central.identifier UUIDString], (unsigned long)[connectedCentrals count]);
            
            // 发送连接通知
            if (bluetoothStateChangedCallback) {
                NSDictionary *connectionInfo = @{
                    @"type": @"connection",
                    @"state": @"connected",
                    @"device": [central.identifier UUIDString],
                    @"characteristic": [[requestedCharacteristic UUID] UUIDString],
                    @"service": [[requestedService UUID] UUIDString]
                };
                
                NSLog(@"📤 Sending connection notification to JavaScript (read request)");
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->bluetoothStateChangedCallback) {
                        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                                   messageAsDictionary:connectionInfo];
                        [pluginResult setKeepCallbackAsBool:TRUE];
                        [self.commandDelegate sendPluginResult:pluginResult callbackId:self->bluetoothStateChangedCallback];
                        NSLog(@"✅ Connection notification sent successfully (read request)");
                    } else {
                        NSLog(@"⚠️ bluetoothStateChangedCallback is nil, cannot send connection notification");
                    }
                });
            } else {
                NSLog(@"⚠️ bluetoothStateChangedCallback is nil, cannot send connection notification");
            }
        } else {
            NSLog(@"📝 Read request from known central: %@", [central.identifier UUIDString]);
        }
    } else {
        NSLog(@"⚠️ Read request has no central information");
    }

    // FUTURE if there is a callback, call into JavaScript for a value
    // otherwise, grab the current value of the characteristic and send it back

    CBCharacteristic *characteristic  = [self findCharacteristicByUUID: [requestedCharacteristic UUID] service:requestedService];

    request.value = [characteristic.value
                     subdataWithRange:NSMakeRange(request.offset,
                                                  characteristic.value.length - request.offset)];

    [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
    [connectedCentrals removeObject:central];
    
    // 通知JavaScript层连接状态变化
    // iOS 18 要求回调必须在主线程中执行
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->bluetoothStateChangedCallback) {
            NSDictionary *connectionInfo = @{
                @"type": @"connection",
                @"state": @"disconnected",
                @"device": [central.identifier UUIDString],
                @"characteristic": [[characteristic UUID] UUIDString]
            };
            
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                           messageAsDictionary:connectionInfo];
            [pluginResult setKeepCallbackAsBool:TRUE];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self->bluetoothStateChangedCallback];
        }
    });
}


- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers");
}

// iOS状态恢复支持
- (void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary<NSString *, id> *)dict {
    NSLog(@"Peripheral manager will restore state");
    
    // 恢复服务
    NSArray *restoredServices = dict[CBPeripheralManagerRestoredStateServicesKey];
    for (CBMutableService *service in restoredServices) {
        NSString *serviceUUID = [[service UUID] UUIDString];
        [services setObject:service forKey:serviceUUID];
        NSLog(@"Restored service: %@", serviceUUID);
    }
    
    // 恢复广播状态
    NSDictionary *advertisementData = dict[CBPeripheralManagerRestoredStateAdvertisementDataKey];
    if (advertisementData) {
        isAdvertising = YES;
        NSLog(@"Restored advertising state");
    }
}

// 处理授权状态变化
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSString *state = [bluetoothStates objectForKey:@(peripheral.state)];
    NSLog(@"Peripheral manager state changed to: %@", state);
    
    // 处理授权状态
    if (peripheral.state == CBPeripheralManagerStateUnauthorized) {
        NSLog(@"Bluetooth permission denied. Please enable Bluetooth access in Settings.");
        
        // iOS 18特定：检查具体的授权状态
        if (@available(iOS 13.1, *)) {
            CBManagerAuthorization authorization = [CBManager authorization];
            switch (authorization) {
                case CBManagerAuthorizationNotDetermined:
                    NSLog(@"Bluetooth authorization not determined");
                    break;
                case CBManagerAuthorizationRestricted:
                    NSLog(@"Bluetooth authorization restricted");
                    break;
                case CBManagerAuthorizationDenied:
                    NSLog(@"Bluetooth authorization denied");
                    break;
                case CBManagerAuthorizationAllowedAlways:
                    NSLog(@"Bluetooth authorization allowed always");
                    break;
            }
        }
    } else if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        NSLog(@"Bluetooth is powered on and ready");
    }

    // 确保在主线程中发送回调
    dispatch_async(dispatch_get_main_queue(), ^{
        if (bluetoothStateChangedCallback) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:state];
            [pluginResult setKeepCallbackAsBool:TRUE];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:bluetoothStateChangedCallback];
        }
    });
}

#pragma mark - Internal Implementation

// Find a characteristic in service with a specific property
-(CBCharacteristic *) findCharacteristicByUUID:(CBUUID *)UUID service:(CBService*)service
{
    NSLog(@"Looking for %@", UUID);
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([c.UUID.UUIDString isEqualToString: UUID.UUIDString]) {
            return c;
        }
    }
    return nil; //Characteristic not found on this service
}

// TODO need errors here to call error callback
- (CBMutableService*) serviceFromJSON:(NSDictionary *)serviceDict {

    NSString *serviceUUIDString = [serviceDict objectForKey:@"uuid"];
    CBUUID *serviceUUID = [CBUUID UUIDWithString: serviceUUIDString];

    // TODO primary should be in the JSON
    CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];

    // create characteristics
    NSMutableArray *characteristics = [NSMutableArray new];
    NSArray *characteristicList = [serviceDict objectForKey:@"characteristics"];
    for (NSDictionary *characteristicData in characteristicList) {

        NSString *characteristicUUIDString = [characteristicData objectForKey:@"uuid"];
        CBUUID *characteristicUUID = [CBUUID UUIDWithString: characteristicUUIDString];

        NSNumber *properties = [characteristicData objectForKey:@"properties"];
        NSString *permissions = [characteristicData objectForKey:@"permissions"];

        CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID properties:[properties intValue] value:nil permissions:[permissions intValue]];

        // add descriptors
        NSMutableArray *descriptors = [NSMutableArray new];
        NSArray *descriptorsList = [characteristicData objectForKey:@"descriptors"];
        for (NSDictionary *descriptorData in descriptorsList) {

            // CBUUIDCharacteristicUserDescriptionString
            NSString *descriptorUUIDString = [descriptorData objectForKey:@"uuid"];
            CBUUID *descriptorUUID = [CBUUID UUIDWithString: descriptorUUIDString];

            // TODO this won't always be a String
            NSString *descriptorValue = [descriptorData objectForKey:@"value"];

            CBMutableDescriptor *descriptor = [[CBMutableDescriptor alloc]
                                               initWithType: descriptorUUID
                                               value:descriptorValue];
            [descriptors addObject:descriptor];
        }

        characteristic.descriptors = descriptors;

        [characteristics addObject: characteristic];
    }

    [service setCharacteristics:characteristics];
    [services setObject:service forKey:[[service UUID] UUIDString]];

    return service;

}

@end

// 蓝牙外设通知功能示例
// 演示如何向连接的中心设备发送通知

// 服务和特征UUID
var SERVICE_UUID = '12345678-1234-1234-1234-123456789ABC';
var NOTIFICATION_CHARACTERISTIC_UUID = '87654321-4321-4321-4321-CBA987654321';
var DATA_CHARACTERISTIC_UUID = '11111111-2222-3333-4444-555555555555';

var app = {
    connectedCentrals: [],
    notificationInterval: null,

    initialize: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
        
        // 添加按钮事件监听器
        document.getElementById('sendNotification').addEventListener('click', this.sendSingleNotification, false);
        document.getElementById('broadcastMessage').addEventListener('click', this.broadcastToAll, false);
        document.getElementById('startAutoNotify').addEventListener('click', this.startAutoNotification, false);
        document.getElementById('stopAutoNotify').addEventListener('click', this.stopAutoNotification, false);
    },

    onDeviceReady: function() {
        console.log('设备就绪，初始化蓝牙外设服务');
        
        // 设置回调
        blePeripheral.onWriteRequest(app.didReceiveWriteRequest);
        blePeripheral.onBluetoothStateChange(app.onBluetoothStateChange);
        
        // 创建服务
        app.createNotificationService();
    },

    createNotificationService: function() {
        var property = blePeripheral.properties;
        var permission = blePeripheral.permissions;

        var notificationService = {
            uuid: SERVICE_UUID,
            characteristics: [
                {
                    uuid: NOTIFICATION_CHARACTERISTIC_UUID,
                    properties: property.READ | property.NOTIFY | property.INDICATE,
                    permissions: permission.READABLE,
                    descriptors: [
                        {
                            uuid: '2901', // Characteristic User Description
                            value: 'Notification Channel'
                        },
                        {
                            uuid: '2902', // Client Characteristic Configuration
                            value: new ArrayBuffer(2) // 初始值为0
                        }
                    ]
                },
                {
                    uuid: DATA_CHARACTERISTIC_UUID,
                    properties: property.READ | property.WRITE | property.NOTIFY,
                    permissions: permission.READABLE | permission.WRITEABLE,
                    descriptors: [
                        {
                            uuid: '2901',
                            value: 'Data Channel'
                        }
                    ]
                }
            ]
        };

        Promise.all([
            blePeripheral.createServiceFromJSON(notificationService),
            blePeripheral.startAdvertising(SERVICE_UUID, 'NotificationDemo')
        ]).then(
            function() { 
                console.log('通知服务创建成功');
                app.updateStatus('服务已创建，等待连接...');
            },
            function(error) {
                console.error('创建服务失败:', error);
                app.updateStatus('创建服务失败: ' + error);
            }
        );
    },

    // 发送单个通知给指定设备或所有设备
    sendSingleNotification: function() {
        var message = document.getElementById('messageInput').value || 'Hello from BLE Peripheral!';
        var data = app.stringToArrayBuffer(message);
        
        blePeripheral.notifyCharacteristicValue(
            SERVICE_UUID, 
            NOTIFICATION_CHARACTERISTIC_UUID, 
            data
        ).then(function(result) {
            console.log('通知发送成功:', result);
            app.updateStatus('通知已发送: ' + message + ' (发送给 ' + result.targetCentralsCount + ' 个设备)');
        }).catch(function(error) {
            console.error('发送通知失败:', error);
            app.updateStatus('发送通知失败: ' + (error.message || error));
        });
    },

    // 广播消息给所有连接的设备
    broadcastToAll: function() {
        var message = document.getElementById('broadcastInput').value || 'Broadcast message to all!';
        var data = app.stringToArrayBuffer(message);
        
        blePeripheral.notifyAllCentrals(
            SERVICE_UUID, 
            NOTIFICATION_CHARACTERISTIC_UUID, 
            data
        ).then(function(result) {
            console.log('广播发送成功:', result);
            app.updateStatus('广播已发送: ' + message + ' (发送给 ' + result.connectedCentralsCount + ' 个设备)');
        }).catch(function(error) {
            console.error('广播失败:', error);
            app.updateStatus('广播失败: ' + (error.message || error));
        });
    },

    // 开始自动通知（每5秒发送一次时间戳）
    startAutoNotification: function() {
        if (app.notificationInterval) {
            app.stopAutoNotification();
        }
        
        app.notificationInterval = setInterval(function() {
            var timestamp = new Date().toLocaleTimeString();
            var message = 'Auto notification: ' + timestamp;
            var data = app.stringToArrayBuffer(message);
            
            blePeripheral.notifyAllCentrals(
                SERVICE_UUID, 
                NOTIFICATION_CHARACTERISTIC_UUID, 
                data
            ).then(function(result) {
                console.log('自动通知发送:', message);
                app.updateStatus('自动通知: ' + timestamp);
            }).catch(function(error) {
                console.error('自动通知失败:', error);
            });
        }, 5000);
        
        app.updateStatus('自动通知已启动（每5秒）');
        document.getElementById('startAutoNotify').disabled = true;
        document.getElementById('stopAutoNotify').disabled = false;
    },

    // 停止自动通知
    stopAutoNotification: function() {
        if (app.notificationInterval) {
            clearInterval(app.notificationInterval);
            app.notificationInterval = null;
        }
        
        app.updateStatus('自动通知已停止');
        document.getElementById('startAutoNotify').disabled = false;
        document.getElementById('stopAutoNotify').disabled = true;
    },

    // 处理写入请求
    didReceiveWriteRequest: function(request) {
        console.log('收到写入请求:', request);
        
        var message = app.arrayBufferToString(request.value);
        app.updateStatus('收到消息: ' + message);
        
        // 自动回复确认消息
        var replyMessage = 'Received: ' + message;
        var replyData = app.stringToArrayBuffer(replyMessage);
        
        blePeripheral.notifyCharacteristicValue(
            request.service,
            NOTIFICATION_CHARACTERISTIC_UUID,
            replyData
        ).then(function() {
            console.log('自动回复已发送');
        }).catch(function(error) {
            console.error('自动回复失败:', error);
        });
    },

    // 蓝牙状态变化处理
    onBluetoothStateChange: function(data) {
        console.log('蓝牙状态变化:', data);
        
        if (typeof data === 'string') {
            // 蓝牙适配器状态
            app.updateStatus('蓝牙状态: ' + data);
        } else if (data && data.type === 'connection') {
            // 设备连接状态变化
            if (data.state === 'connected') {
                app.updateStatus('设备已连接: ' + data.device);
                // 发送欢迎消息
                var welcomeMessage = 'Welcome! Device connected at ' + new Date().toLocaleTimeString();
                var welcomeData = app.stringToArrayBuffer(welcomeMessage);
                
                setTimeout(function() {
                    blePeripheral.notifyCharacteristicValue(
                        SERVICE_UUID,
                        NOTIFICATION_CHARACTERISTIC_UUID,
                        welcomeData
                    ).then(function() {
                        console.log('欢迎消息已发送');
                    }).catch(function(error) {
                        console.error('发送欢迎消息失败:', error);
                    });
                }, 1000); // 延迟1秒发送，确保连接稳定
                
            } else if (data.state === 'disconnected') {
                app.updateStatus('设备已断开: ' + data.device);
            }
        }
    },

    // 工具方法
    stringToArrayBuffer: function(str) {
        var buf = new ArrayBuffer(str.length);
        var bufView = new Uint8Array(buf);
        for (var i = 0, strLen = str.length; i < strLen; i++) {
            bufView[i] = str.charCodeAt(i);
        }
        return buf;
    },

    arrayBufferToString: function(buffer) {
        return String.fromCharCode.apply(null, new Uint8Array(buffer));
    },

    updateStatus: function(message) {
        var statusDiv = document.getElementById('status');
        var timestamp = new Date().toLocaleTimeString();
        statusDiv.innerHTML += '<div>[' + timestamp + '] ' + message + '</div>';
        statusDiv.scrollTop = statusDiv.scrollHeight;
    }
};

app.initialize();

// iOS 18 回调功能测试脚本
// 专门测试 onBluetoothStateChange 和 onWriteRequest 回调

var SERVICE_UUID = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
var TX_UUID = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
var RX_UUID = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

var callbackTestApp = {
    writeRequestCount: 0,
    stateChangeCount: 0,
    connectionEvents: [],

    initialize: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
        
        // 添加按钮事件监听器
        document.getElementById('setupCallbacks').addEventListener('click', this.setupCallbacks, false);
        document.getElementById('createTestService').addEventListener('click', this.createTestService, false);
        document.getElementById('startAdvertising').addEventListener('click', this.startAdvertising, false);
        document.getElementById('clearLogs').addEventListener('click', this.clearLogs, false);
        document.getElementById('testCallbacks').addEventListener('click', this.testCallbacks, false);
    },

    onDeviceReady: function() {
        console.log('设备就绪，准备测试回调功能');
        callbackTestApp.updateStatus('设备就绪，点击"设置回调"开始测试');
        
        // 自动设置回调
        callbackTestApp.setupCallbacks();
    },

    setupCallbacks: function() {
        callbackTestApp.updateStatus('设置回调监听器...');
        
        // 设置写入请求回调
        blePeripheral.onWriteRequest(function(request) {
            callbackTestApp.writeRequestCount++;
            console.log('收到写入请求 #' + callbackTestApp.writeRequestCount + ':', request);
            
            callbackTestApp.updateStatus('✅ 写入请求回调工作正常 (#' + callbackTestApp.writeRequestCount + ')');
            callbackTestApp.updateStatus('  服务: ' + request.service);
            callbackTestApp.updateStatus('  特征: ' + request.characteristic);
            
            if (request.value) {
                var data = new Uint8Array(request.value);
                var message = '';
                for (var i = 0; i < data.length; i++) {
                    message += String.fromCharCode(data[i]);
                }
                callbackTestApp.updateStatus('  数据: "' + message + '"');
                callbackTestApp.updateStatus('  字节数: ' + data.length);
            }
            
            // 更新统计
            document.getElementById('writeRequestCount').textContent = callbackTestApp.writeRequestCount;
        });
        
        // 设置蓝牙状态变化回调
        blePeripheral.onBluetoothStateChange(function(data) {
            callbackTestApp.stateChangeCount++;
            console.log('蓝牙状态变化 #' + callbackTestApp.stateChangeCount + ':', data);
            
            if (typeof data === 'string') {
                // 蓝牙适配器状态变化
                callbackTestApp.updateStatus('🔵 蓝牙状态变化 (#' + callbackTestApp.stateChangeCount + '): ' + data);
            } else if (data && typeof data === 'object' && data.type === 'connection') {
                // 连接状态变化
                callbackTestApp.connectionEvents.push(data);
                callbackTestApp.updateStatus('🔗 连接状态变化 (#' + callbackTestApp.stateChangeCount + '):');
                callbackTestApp.updateStatus('  设备: ' + data.device);
                callbackTestApp.updateStatus('  状态: ' + data.state);
                callbackTestApp.updateStatus('  特征: ' + data.characteristic);
                
                // 更新连接统计
                document.getElementById('connectionCount').textContent = callbackTestApp.connectionEvents.length;
            } else {
                callbackTestApp.updateStatus('🔵 蓝牙状态变化 (#' + callbackTestApp.stateChangeCount + '): ' + JSON.stringify(data));
            }
            
            // 更新统计
            document.getElementById('stateChangeCount').textContent = callbackTestApp.stateChangeCount;
        });
        
        callbackTestApp.updateStatus('✅ 回调监听器设置完成');
    },

    createTestService: function() {
        callbackTestApp.updateStatus('创建测试服务...');
        
        var property = blePeripheral.properties;
        var permission = blePeripheral.permissions;
        
        var uartService = {
            uuid: SERVICE_UUID,
            characteristics: [
                {
                    uuid: TX_UUID,
                    properties: property.WRITE,
                    permissions: permission.WRITEABLE,
                    descriptors: [
                        {
                            uuid: '2901',
                            value: 'TX Characteristic'
                        }
                    ]
                },
                {
                    uuid: RX_UUID,
                    properties: property.READ | property.NOTIFY,
                    permissions: permission.READABLE,
                    descriptors: [
                        {
                            uuid: '2901',
                            value: 'RX Characteristic'
                        }
                    ]
                }
            ]
        };
        
        blePeripheral.createServiceFromJSON(uartService)
            .then(function(result) {
                console.log('服务创建成功:', result);
                callbackTestApp.updateStatus('✅ 测试服务创建成功');
                
                if (result && result.deviceIdentifier) {
                    callbackTestApp.updateStatus('  设备标识: ' + result.deviceIdentifier);
                }
            })
            .catch(function(error) {
                console.error('服务创建失败:', error);
                callbackTestApp.updateStatus('❌ 服务创建失败: ' + JSON.stringify(error));
            });
    },

    startAdvertising: function() {
        callbackTestApp.updateStatus('开始广播...');
        
        blePeripheral.startAdvertising(SERVICE_UUID, 'CallbackTest')
            .then(function(result) {
                console.log('广播启动成功:', result);
                callbackTestApp.updateStatus('✅ 广播启动成功');
                
                if (result && result.advertisingSessionId) {
                    callbackTestApp.updateStatus('  广播会话ID: ' + result.advertisingSessionId);
                }
                if (result && result.deviceIdentifier) {
                    callbackTestApp.updateStatus('  设备标识: ' + result.deviceIdentifier);
                }
                
                callbackTestApp.updateStatus('📱 现在可以使用BLE扫描应用连接到此设备进行测试');
                callbackTestApp.updateStatus('📝 连接后尝试写入数据到TX特征以触发写入请求回调');
            })
            .catch(function(error) {
                console.error('广播启动失败:', error);
                callbackTestApp.updateStatus('❌ 广播启动失败: ' + JSON.stringify(error));
            });
    },

    testCallbacks: function() {
        callbackTestApp.updateStatus('执行回调功能测试...');
        
        // 测试蓝牙状态获取
        blePeripheral.getBluetoothState()
            .then(function(state) {
                callbackTestApp.updateStatus('当前蓝牙状态: ' + JSON.stringify(state, null, 2));
                
                // 测试获取连接信息
                return blePeripheral.getConnectedCentrals();
            })
            .then(function(centrals) {
                callbackTestApp.updateStatus('当前连接的设备数: ' + centrals.length);
                
                if (centrals.length > 0) {
                    callbackTestApp.updateStatus('连接的设备:');
                    centrals.forEach(function(central, index) {
                        callbackTestApp.updateStatus('  设备' + (index + 1) + ': ' + central.identifier);
                    });
                }
                
                // 如果有连接的设备，尝试发送通知
                if (centrals.length > 0) {
                    var testMessage = 'Test notification from peripheral';
                    var testData = callbackTestApp.stringToArrayBuffer(testMessage);
                    
                    return blePeripheral.notifyCharacteristicValue(SERVICE_UUID, RX_UUID, testData);
                }
            })
            .then(function(result) {
                if (result) {
                    callbackTestApp.updateStatus('✅ 测试通知发送成功');
                }
            })
            .catch(function(error) {
                console.error('测试失败:', error);
                callbackTestApp.updateStatus('❌ 测试失败: ' + JSON.stringify(error));
            });
    },

    clearLogs: function() {
        document.getElementById('status').innerHTML = '';
        callbackTestApp.writeRequestCount = 0;
        callbackTestApp.stateChangeCount = 0;
        callbackTestApp.connectionEvents = [];
        
        document.getElementById('writeRequestCount').textContent = '0';
        document.getElementById('stateChangeCount').textContent = '0';
        document.getElementById('connectionCount').textContent = '0';
        
        callbackTestApp.updateStatus('日志已清空');
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

    updateStatus: function(message) {
        var statusDiv = document.getElementById('status');
        if (statusDiv) {
            var timestamp = new Date().toLocaleTimeString();
            statusDiv.innerHTML += '<div>[' + timestamp + '] ' + message + '</div>';
            statusDiv.scrollTop = statusDiv.scrollHeight;
        }
        console.log('[CALLBACK_TEST]', message);
    }
};

// 全局暴露
window.callbackTestApp = callbackTestApp;

callbackTestApp.initialize();

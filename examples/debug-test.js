// iOS 18 调试测试脚本
// 用于诊断和解决null响应问题

var SERVICE_UUID = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
var TX_UUID = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
var RX_UUID = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

var debugApp = {
    initialize: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
    },

    onDeviceReady: function() {
        console.log('设备就绪，开始调试测试');
        debugApp.runDiagnostics();
    },

    runDiagnostics: function() {
        console.log('=== 开始诊断测试 ===');
        
        // 1. 获取设备信息
        debugApp.getDeviceInfo()
            .then(function() {
                // 2. 检查蓝牙状态
                return debugApp.checkBluetoothState();
            })
            .then(function() {
                // 3. 检查管理器信息
                return debugApp.checkManagerInfo();
            })
            .then(function() {
                // 4. 测试创建服务
                return debugApp.testCreateService();
            })
            .then(function() {
                // 5. 测试添加特征
                return debugApp.testAddCharacteristics();
            })
            .then(function() {
                // 6. 测试发布服务
                return debugApp.testPublishService();
            })
            .then(function() {
                // 7. 测试开始广播
                return debugApp.testStartAdvertising();
            })
            .then(function() {
                // 8. 获取完整外设信息
                return debugApp.getCompletePeripheralInfo();
            })
            .then(function() {
                console.log('=== 所有测试完成 ===');
                debugApp.updateStatus('所有测试完成，请查看控制台日志');
            })
            .catch(function(error) {
                console.error('测试过程中出现错误:', error);
                debugApp.updateStatus('测试失败: ' + JSON.stringify(error));
            });
    },

    checkBluetoothState: function() {
        console.log('1. 检查蓝牙状态...');
        debugApp.updateStatus('检查蓝牙状态...');
        
        return blePeripheral.getBluetoothState()
            .then(function(state) {
                console.log('蓝牙状态:', state);
                debugApp.updateStatus('蓝牙状态: ' + JSON.stringify(state, null, 2));
                
                if (state.state !== 'on') {
                    throw new Error('蓝牙未开启，当前状态: ' + state.state);
                }
                
                if (state.authorizationString && state.authorizationString !== 'allowedAlways') {
                    console.warn('蓝牙权限可能有问题:', state.authorizationString);
                }
                
                return state;
            });
    },

    checkManagerInfo: function() {
        console.log('2. 检查管理器信息...');
        debugApp.updateStatus('检查管理器信息...');
        
        return blePeripheral.getManagerInfo()
            .then(function(info) {
                console.log('管理器信息:', info);
                debugApp.updateStatus('管理器信息: ' + JSON.stringify(info, null, 2));
                
                if (!info.managerExists) {
                    throw new Error('CBPeripheralManager未正确初始化');
                }
                
                return info;
            });
    },

    testCreateService: function() {
        console.log('3. 测试创建服务...');
        debugApp.updateStatus('测试创建服务...');
        
        return new Promise(function(resolve, reject) {
            var startTime = Date.now();
            
            blePeripheral.createService(SERVICE_UUID)
                .then(function(result) {
                    var endTime = Date.now();
                    console.log('创建服务成功:', result, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('✅ 创建服务成功，耗时: ' + (endTime - startTime) + 'ms');
                    resolve(result);
                })
                .catch(function(error) {
                    var endTime = Date.now();
                    console.error('创建服务失败:', error, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('❌ 创建服务失败: ' + JSON.stringify(error));
                    reject(error);
                });
                
            // 设置超时检测
            setTimeout(function() {
                console.warn('创建服务操作超时 (5秒)');
                debugApp.updateStatus('⚠️ 创建服务操作超时');
            }, 5000);
        });
    },

    testAddCharacteristics: function() {
        console.log('4. 测试添加特征...');
        debugApp.updateStatus('测试添加特征...');
        
        var property = blePeripheral.properties;
        var permission = blePeripheral.permissions;
        
        var promises = [
            debugApp.testAddSingleCharacteristic(SERVICE_UUID, TX_UUID, property.WRITE, permission.WRITEABLE, 'TX'),
            debugApp.testAddSingleCharacteristic(SERVICE_UUID, RX_UUID, property.READ | property.NOTIFY, permission.READABLE, 'RX')
        ];
        
        return Promise.all(promises);
    },

    testAddSingleCharacteristic: function(serviceUUID, charUUID, properties, permissions, name) {
        return new Promise(function(resolve, reject) {
            var startTime = Date.now();
            
            blePeripheral.addCharacteristic(serviceUUID, charUUID, properties, permissions)
                .then(function(result) {
                    var endTime = Date.now();
                    console.log('添加' + name + '特征成功:', result, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('✅ 添加' + name + '特征成功，耗时: ' + (endTime - startTime) + 'ms');
                    resolve(result);
                })
                .catch(function(error) {
                    var endTime = Date.now();
                    console.error('添加' + name + '特征失败:', error, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('❌ 添加' + name + '特征失败: ' + JSON.stringify(error));
                    reject(error);
                });
                
            // 设置超时检测
            setTimeout(function() {
                console.warn('添加' + name + '特征操作超时 (5秒)');
            }, 5000);
        });
    },

    testPublishService: function() {
        console.log('5. 测试发布服务...');
        debugApp.updateStatus('测试发布服务...');
        
        return new Promise(function(resolve, reject) {
            var startTime = Date.now();
            
            blePeripheral.publishService(SERVICE_UUID)
                .then(function(result) {
                    var endTime = Date.now();
                    console.log('发布服务成功:', result, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('✅ 发布服务成功，耗时: ' + (endTime - startTime) + 'ms');
                    resolve(result);
                })
                .catch(function(error) {
                    var endTime = Date.now();
                    console.error('发布服务失败:', error, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('❌ 发布服务失败: ' + JSON.stringify(error));
                    reject(error);
                });
                
            // 设置超时检测
            setTimeout(function() {
                console.warn('发布服务操作超时 (10秒)');
                debugApp.updateStatus('⚠️ 发布服务操作超时 (这是异步操作，可能需要更长时间)');
            }, 10000);
        });
    },

    testStartAdvertising: function() {
        console.log('6. 测试开始广播...');
        debugApp.updateStatus('测试开始广播...');
        
        return new Promise(function(resolve, reject) {
            var startTime = Date.now();
            
            blePeripheral.startAdvertising(SERVICE_UUID, 'DebugTest')
                .then(function(result) {
                    var endTime = Date.now();
                    console.log('开始广播成功:', result, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('✅ 开始广播成功，耗时: ' + (endTime - startTime) + 'ms');
                    resolve(result);
                })
                .catch(function(error) {
                    var endTime = Date.now();
                    console.error('开始广播失败:', error, '耗时:', (endTime - startTime) + 'ms');
                    debugApp.updateStatus('❌ 开始广播失败: ' + JSON.stringify(error));
                    reject(error);
                });
                
            // 设置超时检测
            setTimeout(function() {
                console.warn('开始广播操作超时 (10秒)');
                debugApp.updateStatus('⚠️ 开始广播操作超时');
            }, 10000);
        });
    },

    updateStatus: function(message) {
        var statusDiv = document.getElementById('debugStatus');
        if (statusDiv) {
            var timestamp = new Date().toLocaleTimeString();
            statusDiv.innerHTML += '<div>[' + timestamp + '] ' + message + '</div>';
            statusDiv.scrollTop = statusDiv.scrollHeight;
        }
        console.log('[DEBUG]', message);
    },

    getDeviceInfo: function() {
        console.log('0. 获取设备信息...');
        debugApp.updateStatus('获取设备信息...');
        
        return blePeripheral.getLocalBluetoothInfo()
            .then(function(info) {
                console.log('本地蓝牙信息:', info);
                debugApp.updateStatus('📱 设备信息获取成功:');
                debugApp.updateStatus('  设备标识: ' + (info.deviceIdentifier || 'N/A'));
                debugApp.updateStatus('  iOS版本: ' + info.iOSVersion);
                debugApp.updateStatus('  蓝牙状态: ' + info.stateString);
                debugApp.updateStatus('  会话ID: ' + info.sessionId);
                
                return info;
            });
    },

    getCompletePeripheralInfo: function() {
        console.log('8. 获取完整外设信息...');
        debugApp.updateStatus('获取完整外设信息...');
        
        return blePeripheral.getPeripheralInfo()
            .then(function(info) {
                console.log('完整外设信息:', info);
                debugApp.updateStatus('📊 完整外设信息:');
                debugApp.updateStatus('  设备名称: ' + info.deviceName);
                debugApp.updateStatus('  设备标识: ' + info.deviceIdentifier);
                debugApp.updateStatus('  设备型号: ' + info.deviceModel);
                debugApp.updateStatus('  系统版本: ' + info.systemVersion);
                debugApp.updateStatus('  蓝牙状态: ' + info.bluetoothStateString);
                debugApp.updateStatus('  广播状态: ' + (info.isAdvertising ? '正在广播' : '未广播'));
                debugApp.updateStatus('  已发布服务数: ' + info.services.length);
                debugApp.updateStatus('  连接的设备数: ' + info.connectedCentrals.length);
                
                if (info.services.length > 0) {
                    debugApp.updateStatus('  服务详情:');
                    info.services.forEach(function(service, index) {
                        debugApp.updateStatus('    服务' + (index + 1) + ': ' + service.uuid);
                        debugApp.updateStatus('      特征数量: ' + service.characteristicsCount);
                        debugApp.updateStatus('      主要服务: ' + (service.isPrimary ? '是' : '否'));
                    });
                }
                
                return info;
            });
    },

    // 手动测试单个方法
    testSingleMethod: function(methodName) {
        switch(methodName) {
            case 'createService':
                debugApp.testCreateService();
                break;
            case 'addCharacteristic':
                debugApp.testAddCharacteristics();
                break;
            case 'publishService':
                debugApp.testPublishService();
                break;
            case 'startAdvertising':
                debugApp.testStartAdvertising();
                break;
            case 'bluetoothState':
                debugApp.checkBluetoothState();
                break;
            case 'managerInfo':
                debugApp.checkManagerInfo();
                break;
            case 'deviceInfo':
                debugApp.getDeviceInfo();
                break;
            case 'peripheralInfo':
                debugApp.getCompletePeripheralInfo();
                break;
            default:
                console.log('未知的测试方法:', methodName);
        }
    }
};

// 全局暴露调试方法
window.debugBLE = debugApp;

debugApp.initialize();

// 设备信息展示示例
// 演示如何获取和显示蓝牙外设的详细信息

var deviceInfoApp = {
    initialize: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
        
        // 添加按钮事件监听器
        document.getElementById('getDeviceInfo').addEventListener('click', this.getDeviceInfo, false);
        document.getElementById('getPeripheralInfo').addEventListener('click', this.getPeripheralInfo, false);
        document.getElementById('getBluetoothInfo').addEventListener('click', this.getBluetoothInfo, false);
        document.getElementById('createTestService').addEventListener('click', this.createTestService, false);
        document.getElementById('refreshInfo').addEventListener('click', this.refreshAllInfo, false);
    },

    onDeviceReady: function() {
        console.log('设备就绪，初始化设备信息展示');
        deviceInfoApp.updateStatus('设备就绪，点击按钮获取信息');
        
        // 自动获取基本信息
        deviceInfoApp.getBluetoothInfo();
    },

    getDeviceInfo: function() {
        deviceInfoApp.updateStatus('正在获取设备信息...');
        
        blePeripheral.getLocalBluetoothInfo()
            .then(function(info) {
                console.log('设备信息:', info);
                deviceInfoApp.displayDeviceInfo(info);
            })
            .catch(function(error) {
                console.error('获取设备信息失败:', error);
                deviceInfoApp.updateStatus('❌ 获取设备信息失败: ' + JSON.stringify(error));
            });
    },

    getPeripheralInfo: function() {
        deviceInfoApp.updateStatus('正在获取外设信息...');
        
        blePeripheral.getPeripheralInfo()
            .then(function(info) {
                console.log('外设信息:', info);
                deviceInfoApp.displayPeripheralInfo(info);
            })
            .catch(function(error) {
                console.error('获取外设信息失败:', error);
                deviceInfoApp.updateStatus('❌ 获取外设信息失败: ' + JSON.stringify(error));
            });
    },

    getBluetoothInfo: function() {
        deviceInfoApp.updateStatus('正在获取蓝牙状态...');
        
        blePeripheral.getBluetoothState()
            .then(function(state) {
                console.log('蓝牙状态:', state);
                deviceInfoApp.displayBluetoothState(state);
            })
            .catch(function(error) {
                console.error('获取蓝牙状态失败:', error);
                deviceInfoApp.updateStatus('❌ 获取蓝牙状态失败: ' + JSON.stringify(error));
            });
    },

    createTestService: function() {
        deviceInfoApp.updateStatus('创建测试服务以获取更多信息...');
        
        var SERVICE_UUID = '12345678-1234-1234-1234-123456789ABC';
        var CHAR_UUID = '87654321-4321-4321-4321-CBA987654321';
        
        var property = blePeripheral.properties;
        var permission = blePeripheral.permissions;
        
        Promise.all([
            blePeripheral.createService(SERVICE_UUID),
            blePeripheral.addCharacteristic(SERVICE_UUID, CHAR_UUID, property.READ | property.NOTIFY, permission.READABLE)
        ]).then(function(results) {
            console.log('测试服务创建结果:', results);
            deviceInfoApp.updateStatus('✅ 测试服务创建成功');
            
            // 显示创建结果中的设备信息
            if (results[0] && results[0].deviceIdentifier) {
                deviceInfoApp.updateStatus('📱 设备标识符: ' + results[0].deviceIdentifier);
                deviceInfoApp.updateStatus('📱 设备名称: ' + results[0].deviceName);
            }
            
            // 发布服务
            return blePeripheral.publishService(SERVICE_UUID);
        }).then(function(result) {
            console.log('服务发布结果:', result);
            deviceInfoApp.updateStatus('✅ 服务发布成功');
            
            if (result && result.deviceIdentifier) {
                deviceInfoApp.updateStatus('📡 广播设备标识: ' + result.deviceIdentifier);
            }
            
            // 开始广播
            return blePeripheral.startAdvertising(SERVICE_UUID, 'DeviceInfoTest');
        }).then(function(result) {
            console.log('广播启动结果:', result);
            deviceInfoApp.updateStatus('✅ 广播启动成功');
            
            // 显示详细的广播信息
            if (result) {
                deviceInfoApp.displayAdvertisingInfo(result);
            }
            
            // 获取完整信息
            return deviceInfoApp.getPeripheralInfo();
        }).catch(function(error) {
            console.error('创建测试服务失败:', error);
            deviceInfoApp.updateStatus('❌ 创建测试服务失败: ' + JSON.stringify(error));
        });
    },

    refreshAllInfo: function() {
        deviceInfoApp.updateStatus('刷新所有信息...');
        
        Promise.all([
            blePeripheral.getLocalBluetoothInfo(),
            blePeripheral.getPeripheralInfo(),
            blePeripheral.getBluetoothState()
        ]).then(function(results) {
            var bluetoothInfo = results[0];
            var peripheralInfo = results[1];
            var bluetoothState = results[2];
            
            console.log('所有信息:', { bluetoothInfo, peripheralInfo, bluetoothState });
            
            deviceInfoApp.displayDeviceInfo(bluetoothInfo);
            deviceInfoApp.displayPeripheralInfo(peripheralInfo);
            deviceInfoApp.displayBluetoothState(bluetoothState);
            
            deviceInfoApp.updateStatus('✅ 所有信息刷新完成');
        }).catch(function(error) {
            console.error('刷新信息失败:', error);
            deviceInfoApp.updateStatus('❌ 刷新信息失败: ' + JSON.stringify(error));
        });
    },

    displayDeviceInfo: function(info) {
        var deviceInfoDiv = document.getElementById('deviceInfo');
        var html = '<h4>📱 设备信息</h4>';
        
        if (info.sessionId) {
            html += '<p><strong>会话ID:</strong> ' + info.sessionId + '</p>';
        }
        if (info.iOSVersion) {
            html += '<p><strong>iOS版本:</strong> ' + info.iOSVersion + '</p>';
        }
        if (info.stateString) {
            html += '<p><strong>蓝牙状态:</strong> ' + info.stateString + '</p>';
        }
        if (info.authorizationString) {
            html += '<p><strong>蓝牙权限:</strong> ' + info.authorizationString + '</p>';
        }
        if (info.role) {
            html += '<p><strong>设备角色:</strong> ' + info.role + '</p>';
        }
        if (info.supportsAdvertising !== undefined) {
            html += '<p><strong>支持广播:</strong> ' + (info.supportsAdvertising ? '是' : '否') + '</p>';
        }
        if (info.maxAdvertisingDataLength) {
            html += '<p><strong>最大广播数据长度:</strong> ' + info.maxAdvertisingDataLength + ' 字节</p>';
        }
        if (info.publishedServicesCount !== undefined) {
            html += '<p><strong>已发布服务数:</strong> ' + info.publishedServicesCount + '</p>';
        }
        if (info.connectedCentralsCount !== undefined) {
            html += '<p><strong>连接的设备数:</strong> ' + info.connectedCentralsCount + '</p>';
        }
        
        html += '<p><strong>时间戳:</strong> ' + new Date(info.timestamp * 1000).toLocaleString() + '</p>';
        
        deviceInfoDiv.innerHTML = html;
    },

    displayPeripheralInfo: function(info) {
        var peripheralInfoDiv = document.getElementById('peripheralInfo');
        var html = '<h4>📊 外设信息</h4>';
        
        html += '<p><strong>设备名称:</strong> ' + (info.deviceName || 'N/A') + '</p>';
        html += '<p><strong>设备型号:</strong> ' + (info.deviceModel || 'N/A') + '</p>';
        html += '<p><strong>设备标识符:</strong> ' + (info.deviceIdentifier || 'N/A') + '</p>';
        html += '<p><strong>系统名称:</strong> ' + (info.systemName || 'N/A') + '</p>';
        html += '<p><strong>系统版本:</strong> ' + (info.systemVersion || 'N/A') + '</p>';
        
        if (info.bluetoothStateString) {
            html += '<p><strong>蓝牙状态:</strong> ' + info.bluetoothStateString + '</p>';
        }
        if (info.isAdvertising !== undefined) {
            html += '<p><strong>广播状态:</strong> ' + (info.isAdvertising ? '正在广播' : '未广播') + '</p>';
        }
        if (info.bluetoothAuthorizationString) {
            html += '<p><strong>蓝牙权限:</strong> ' + info.bluetoothAuthorizationString + '</p>';
        }
        
        // 服务信息
        if (info.services && info.services.length > 0) {
            html += '<h5>📡 已发布的服务 (' + info.services.length + '个)</h5>';
            info.services.forEach(function(service, index) {
                html += '<div style="margin-left: 20px; border-left: 2px solid #007AFF; padding-left: 10px; margin-bottom: 10px;">';
                html += '<p><strong>服务 ' + (index + 1) + ':</strong></p>';
                html += '<p>UUID: ' + service.uuid + '</p>';
                html += '<p>特征数量: ' + service.characteristicsCount + '</p>';
                html += '<p>主要服务: ' + (service.isPrimary ? '是' : '否') + '</p>';
                
                if (service.characteristics && service.characteristics.length > 0) {
                    html += '<p><strong>特征列表:</strong></p>';
                    service.characteristics.forEach(function(char, charIndex) {
                        html += '<div style="margin-left: 15px; font-size: 14px;">';
                        html += '<p>特征 ' + (charIndex + 1) + ': ' + char.uuid + '</p>';
                        html += '<p>属性: ' + char.properties + ' | 权限: ' + char.permissions + '</p>';
                        if (char.descriptorsCount > 0) {
                            html += '<p>描述符数量: ' + char.descriptorsCount + '</p>';
                        }
                        html += '</div>';
                    });
                }
                html += '</div>';
            });
        } else {
            html += '<p><strong>已发布的服务:</strong> 无</p>';
        }
        
        // 连接的设备信息
        if (info.connectedCentrals && info.connectedCentrals.length > 0) {
            html += '<h5>🔗 连接的中心设备 (' + info.connectedCentrals.length + '个)</h5>';
            info.connectedCentrals.forEach(function(central, index) {
                html += '<div style="margin-left: 20px; border-left: 2px solid #34C759; padding-left: 10px; margin-bottom: 10px;">';
                html += '<p><strong>设备 ' + (index + 1) + ':</strong></p>';
                html += '<p>标识符: ' + central.identifier + '</p>';
                html += '<p>最大更新长度: ' + central.maximumUpdateValueLength + ' 字节</p>';
                html += '</div>';
            });
        } else {
            html += '<p><strong>连接的中心设备:</strong> 无</p>';
        }
        
        html += '<p><strong>时间戳:</strong> ' + new Date(info.timestamp * 1000).toLocaleString() + '</p>';
        
        peripheralInfoDiv.innerHTML = html;
    },

    displayBluetoothState: function(state) {
        var bluetoothStateDiv = document.getElementById('bluetoothState');
        var html = '<h4>🔵 蓝牙状态</h4>';
        
        html += '<p><strong>状态:</strong> ' + (state.state || 'N/A') + '</p>';
        html += '<p><strong>状态码:</strong> ' + (state.stateCode || 'N/A') + '</p>';
        
        if (state.authorizationString) {
            html += '<p><strong>权限状态:</strong> ' + state.authorizationString + '</p>';
        }
        if (state.authorization !== undefined) {
            html += '<p><strong>权限码:</strong> ' + state.authorization + '</p>';
        }
        if (state.isAdvertising !== undefined) {
            html += '<p><strong>广播状态:</strong> ' + (state.isAdvertising ? '正在广播' : '未广播') + '</p>';
        }
        if (state.connectedCentralsCount !== undefined) {
            html += '<p><strong>连接设备数:</strong> ' + state.connectedCentralsCount + '</p>';
        }
        if (state.servicesCount !== undefined) {
            html += '<p><strong>服务数量:</strong> ' + state.servicesCount + '</p>';
        }
        
        bluetoothStateDiv.innerHTML = html;
    },

    displayAdvertisingInfo: function(info) {
        deviceInfoApp.updateStatus('📡 广播信息:');
        deviceInfoApp.updateStatus('  设备名称: ' + (info.deviceName || 'N/A'));
        deviceInfoApp.updateStatus('  设备型号: ' + (info.deviceModel || 'N/A'));
        deviceInfoApp.updateStatus('  设备标识: ' + (info.deviceIdentifier || 'N/A'));
        deviceInfoApp.updateStatus('  iOS版本: ' + (info.iOSVersion || 'N/A'));
        deviceInfoApp.updateStatus('  蓝牙状态: ' + (info.bluetoothStateString || 'N/A'));
        deviceInfoApp.updateStatus('  权限状态: ' + (info.bluetoothAuthorizationString || 'N/A'));
        deviceInfoApp.updateStatus('  广播会话ID: ' + (info.advertisingSessionId || 'N/A'));
        deviceInfoApp.updateStatus('  已发布服务数: ' + (info.publishedServicesCount || 0));
    },

    updateStatus: function(message) {
        var statusDiv = document.getElementById('status');
        if (statusDiv) {
            var timestamp = new Date().toLocaleTimeString();
            statusDiv.innerHTML += '<div>[' + timestamp + '] ' + message + '</div>';
            statusDiv.scrollTop = statusDiv.scrollHeight;
        }
        console.log('[DEVICE_INFO]', message);
    }
};

// 全局暴露
window.deviceInfoApp = deviceInfoApp;

deviceInfoApp.initialize();

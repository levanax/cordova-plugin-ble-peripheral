# iOS 兼容性指南

## 概述

本文档详细说明了 Cordova BLE Peripheral 插件在 iOS 平台上的兼容性要求和解决方案。

## 支持的iOS版本

- **最低支持版本**: iOS 12.0
- **推荐版本**: iOS 15.0+
- **完全测试版本**: iOS 17.x, iOS 18.x

## 主要兼容性问题及解决方案

### 1. 蓝牙权限配置 (iOS 13+)

**问题**: iOS 13 开始要求明确的蓝牙权限描述

**解决方案**: 在 `config.xml` 中添加以下配置：

```xml
<platform name="ios">
    <config-file parent="NSBluetoothAlwaysUsageDescription" target="*-Info.plist">
        <string>此应用需要使用蓝牙与外围设备通信</string>
    </config-file>
    
    <config-file parent="NSBluetoothPeripheralUsageDescription" target="*-Info.plist">
        <string>此应用需要使用蓝牙作为外围设备</string>
    </config-file>
</platform>
```

### 2. 后台模式支持

**问题**: iOS 需要明确声明后台蓝牙使用权限

**解决方案**: 添加后台模式配置：

```xml
<config-file parent="UIBackgroundModes" target="*-Info.plist">
    <array>
        <string>bluetooth-peripheral</string>
    </array>
</config-file>
```

### 3. 状态恢复支持

**新功能**: 支持应用被系统终止后的状态恢复

**实现**: 
- 使用 `CBPeripheralManagerOptionRestoreIdentifierKey` 选项
- 实现 `willRestoreState` 委托方法
- 自动恢复服务和广播状态

### 4. 增强的错误处理

**改进**:
- 更详细的错误信息
- 蓝牙状态检查
- 参数验证
- 连接状态跟踪

### 5. 新增API方法

```javascript
// 停止广播
blePeripheral.stopAdvertising()

// 检查广播状态
blePeripheral.isAdvertising()

// 获取已连接的中心设备
blePeripheral.getConnectedCentrals()

// 移除服务
blePeripheral.removeService(serviceUUID)

// 移除所有服务
blePeripheral.removeAllServices()
```

## 开发环境要求

### Cordova 版本
- **当前支持**: Cordova 13.0.0
- **iOS平台**: cordova-ios 8.0+

### Xcode 要求
- **最低版本**: Xcode 14.0
- **推荐版本**: Xcode 15.0+

## 测试建议

### 1. 真机测试
- 必须在真实iOS设备上测试
- 模拟器不支持蓝牙功能

### 2. 权限测试
- 测试首次启动时的权限请求
- 测试权限被拒绝后的处理

### 3. 后台测试
- 测试应用进入后台后的蓝牙功能
- 测试应用被系统终止后的状态恢复

### 4. 兼容性测试
- 在不同iOS版本上测试
- 测试不同设备型号的兼容性

## 常见问题解决

### 问题1: 蓝牙权限被拒绝
**解决方案**: 
- 检查 Info.plist 中的权限描述
- 引导用户到设置中手动开启权限

### 问题2: 后台广播停止
**解决方案**:
- 确保添加了 `bluetooth-peripheral` 后台模式
- 检查iOS系统的后台应用刷新设置

### 问题3: 状态恢复失败
**解决方案**:
- 确保使用了正确的恢复标识符
- 实现完整的状态恢复逻辑

## 最佳实践

### 1. 错误处理
```javascript
blePeripheral.startAdvertising(serviceUUID, localName)
    .then(() => {
        console.log('广播启动成功');
    })
    .catch((error) => {
        console.error('广播启动失败:', error);
        // 处理具体错误情况
    });
```

### 2. 状态监听
```javascript
blePeripheral.onBluetoothStateChange((data) => {
    if (typeof data === 'string') {
        // 蓝牙适配器状态变化
        console.log('蓝牙状态:', data);
    } else if (data.type === 'connection') {
        // 设备连接状态变化
        console.log('设备连接状态:', data);
    }
});
```

### 3. 生命周期管理
```javascript
// 应用启动时
document.addEventListener('deviceready', () => {
    // 初始化蓝牙服务
});

// 应用暂停时
document.addEventListener('pause', () => {
    // 可选：停止不必要的操作
});

// 应用恢复时
document.addEventListener('resume', () => {
    // 检查蓝牙状态
    // 恢复必要的操作
});
```

## 更新日志

### v1.1.0 (iOS 17/18 兼容性更新)
- ✅ 添加iOS 13+权限支持
- ✅ 增强错误处理
- ✅ 添加状态恢复支持
- ✅ 新增连接状态跟踪
- ✅ 添加新的API方法
- ✅ 优化性能和稳定性

### v1.0.0 (原始版本)
- ✅ 基础BLE外设功能
- ✅ Android/iOS双平台支持
- ✅ 服务和特征管理
- ✅ 广播功能

## 技术支持

如果您在使用过程中遇到问题，请：

1. 检查本文档中的常见问题解决方案
2. 查看示例代码和配置
3. 在GitHub上提交Issue，包含详细的错误信息和环境描述

## 参考资料

- [Apple Core Bluetooth 官方文档](https://developer.apple.com/documentation/corebluetooth)
- [Cordova iOS 平台指南](https://cordova.apache.org/docs/en/latest/guide/platforms/ios/)
- [iOS 应用后台执行指南](https://developer.apple.com/documentation/backgroundtasks)

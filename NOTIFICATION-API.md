# BLE外设通知API文档

## 概述

新增的通知功能允许BLE外设主动向连接的中心设备发送数据，这是BLE通信中的重要功能，特别适用于：

- 传感器数据推送
- 状态变化通知  
- 实时消息传递
- 事件触发通知

## API方法

### 1. notifyCharacteristicValue()

向指定的中心设备发送特征值通知。

**语法:**
```javascript
blePeripheral.notifyCharacteristicValue(serviceUUID, characteristicUUID, value, centralIdentifiers)
```

**参数:**
- `serviceUUID` (String): 服务UUID
- `characteristicUUID` (String): 特征UUID
- `value` (ArrayBuffer): 要发送的数据
- `centralIdentifiers` (Array, 可选): 目标中心设备标识符数组，如果不提供则发送给所有订阅的设备

**返回值:**
返回Promise，成功时包含以下信息：
```javascript
{
    status: "success",
    service: "服务UUID",
    characteristic: "特征UUID", 
    dataLength: 数据长度,
    targetCentralsCount: 目标设备数量
}
```

**示例:**
```javascript
// 发送给所有订阅的设备
var message = "Hello World!";
var data = stringToArrayBuffer(message);

blePeripheral.notifyCharacteristicValue(
    "12345678-1234-1234-1234-123456789ABC",
    "87654321-4321-4321-4321-CBA987654321", 
    data
).then(function(result) {
    console.log("通知发送成功:", result);
}).catch(function(error) {
    console.error("发送失败:", error);
});

// 发送给指定设备
var targetDevices = ["DEVICE-UUID-1", "DEVICE-UUID-2"];
blePeripheral.notifyCharacteristicValue(
    serviceUUID,
    characteristicUUID,
    data,
    targetDevices
).then(function(result) {
    console.log("定向通知发送成功");
});
```

### 2. notifyAllCentrals()

向所有连接的中心设备广播通知。

**语法:**
```javascript
blePeripheral.notifyAllCentrals(serviceUUID, characteristicUUID, value)
```

**参数:**
- `serviceUUID` (String): 服务UUID
- `characteristicUUID` (String): 特征UUID  
- `value` (ArrayBuffer): 要广播的数据

**返回值:**
返回Promise，成功时包含：
```javascript
{
    status: "success",
    service: "服务UUID",
    characteristic: "特征UUID",
    dataLength: 数据长度,
    connectedCentralsCount: 连接设备总数,
    message: "Notification sent to all subscribed centrals"
}
```

**示例:**
```javascript
var broadcastMessage = "系统公告：服务器维护中";
var data = stringToArrayBuffer(broadcastMessage);

blePeripheral.notifyAllCentrals(
    serviceUUID,
    characteristicUUID, 
    data
).then(function(result) {
    console.log("广播成功，发送给", result.connectedCentralsCount, "个设备");
}).catch(function(error) {
    console.error("广播失败:", error);
});
```

## 使用要求

### 1. 特征配置要求

要使用通知功能，特征必须配置为支持通知或指示：

```javascript
var characteristic = {
    uuid: "YOUR-CHARACTERISTIC-UUID",
    properties: blePeripheral.properties.READ | 
                blePeripheral.properties.NOTIFY |    // 支持通知
                blePeripheral.properties.INDICATE,   // 支持指示
    permissions: blePeripheral.permissions.READABLE,
    descriptors: [
        {
            uuid: '2902', // Client Characteristic Configuration Descriptor
            value: new ArrayBuffer(2) // 必需的CCCD描述符
        }
    ]
};
```

### 2. 中心设备订阅

中心设备必须先订阅特征才能接收通知：
- 中心设备需要写入CCCD描述符来启用通知
- 只有订阅了的设备才会收到通知

### 3. 数据格式

- 所有数据必须是`ArrayBuffer`格式
- iOS BLE有数据长度限制（通常为20字节，iOS 10+支持更长）
- 超长数据会被自动分片传输

## 错误处理

### 常见错误及解决方案

**1. "Characteristic does not support notifications"**
```javascript
// 解决：确保特征配置了NOTIFY或INDICATE属性
properties: blePeripheral.properties.NOTIFY | blePeripheral.properties.READ
```

**2. "No connected central devices"**
```javascript
// 解决：检查设备连接状态
blePeripheral.getConnectedCentrals().then(function(centrals) {
    if (centrals.length === 0) {
        console.log("没有连接的设备");
    }
});
```

**3. "Failed to send notification. Transmission queue is full"**
```javascript
// 解决：降低发送频率或等待队列清空
setTimeout(function() {
    // 重试发送
    blePeripheral.notifyCharacteristicValue(serviceUUID, charUUID, data);
}, 100);
```

**4. "Service not found"**
```javascript
// 解决：确保服务已创建并发布
blePeripheral.createServiceFromJSON(serviceConfig)
    .then(function() {
        // 服务创建成功后再发送通知
        return blePeripheral.notifyCharacteristicValue(serviceUUID, charUUID, data);
    });
```

## 最佳实践

### 1. 连接状态监听
```javascript
blePeripheral.onBluetoothStateChange(function(data) {
    if (data.type === 'connection') {
        if (data.state === 'connected') {
            // 设备连接时发送欢迎消息
            var welcomeMsg = stringToArrayBuffer("欢迎连接！");
            blePeripheral.notifyCharacteristicValue(serviceUUID, charUUID, welcomeMsg);
        }
    }
});
```

### 2. 自动回复机制
```javascript
blePeripheral.onWriteRequest(function(request) {
    // 收到写入请求时自动发送确认
    var confirmMsg = stringToArrayBuffer("收到：" + arrayBufferToString(request.value));
    blePeripheral.notifyCharacteristicValue(
        request.service,
        notificationCharUUID,
        confirmMsg
    );
});
```

### 3. 定时推送
```javascript
var pushInterval = setInterval(function() {
    var timestamp = new Date().toISOString();
    var data = stringToArrayBuffer("心跳：" + timestamp);
    
    blePeripheral.notifyAllCentrals(serviceUUID, charUUID, data)
        .catch(function(error) {
            if (error.message.includes("No connected central devices")) {
                // 没有连接设备时暂停推送
                clearInterval(pushInterval);
            }
        });
}, 30000); // 每30秒推送一次
```

### 4. 数据分片处理
```javascript
function sendLongMessage(serviceUUID, charUUID, longMessage) {
    var maxChunkSize = 20; // iOS BLE最大数据包大小
    var chunks = [];
    
    // 分割长消息
    for (var i = 0; i < longMessage.length; i += maxChunkSize) {
        chunks.push(longMessage.substring(i, i + maxChunkSize));
    }
    
    // 依次发送每个分片
    var sendChunk = function(index) {
        if (index >= chunks.length) return Promise.resolve();
        
        var chunkData = stringToArrayBuffer(chunks[index]);
        return blePeripheral.notifyCharacteristicValue(serviceUUID, charUUID, chunkData)
            .then(function() {
                return new Promise(function(resolve) {
                    setTimeout(function() {
                        sendChunk(index + 1).then(resolve);
                    }, 50); // 分片间延迟50ms
                });
            });
    };
    
    return sendChunk(0);
}
```

## 性能考虑

### 1. 发送频率限制
- iOS BLE有传输队列限制
- 建议发送间隔不少于50ms
- 高频发送可能导致数据丢失

### 2. 数据大小优化
- 尽量使用紧凑的数据格式
- 考虑使用二进制协议而非文本
- 避免发送冗余数据

### 3. 连接管理
- 监听连接状态变化
- 及时清理断开的连接
- 合理处理重连逻辑

## 调试技巧

### 1. 启用详细日志
```javascript
// 在发送前后添加日志
console.log("准备发送通知:", {
    service: serviceUUID,
    characteristic: charUUID,
    dataLength: data.byteLength
});

blePeripheral.notifyCharacteristicValue(serviceUUID, charUUID, data)
    .then(function(result) {
        console.log("发送成功:", result);
    })
    .catch(function(error) {
        console.error("发送失败:", error);
    });
```

### 2. 状态检查
```javascript
// 发送前检查系统状态
Promise.all([
    blePeripheral.isAdvertising(),
    blePeripheral.getConnectedCentrals()
]).then(function(results) {
    var isAdvertising = results[0];
    var connectedCentrals = results[1];
    
    console.log("广播状态:", isAdvertising);
    console.log("连接设备数:", connectedCentrals.length);
    
    if (connectedCentrals.length > 0) {
        // 有连接设备时才发送通知
        return blePeripheral.notifyAllCentrals(serviceUUID, charUUID, data);
    }
});
```

## 示例项目

完整的示例代码请参考：
- `examples/notification-example.html` - 完整的通知功能演示
- `examples/notification-example.js` - JavaScript实现示例
- `examples/uart/` - 更新的UART示例，包含通知功能

这些示例展示了如何在实际应用中使用通知功能，包括错误处理、状态管理和用户界面集成。

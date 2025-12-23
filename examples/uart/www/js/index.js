// only works for ASCII characters
function bytesToString(buffer) {
    return String.fromCharCode.apply(null, new Uint8Array(buffer));
}

// only works for ASCII characters
function stringToBytes(string) {
    var array = new Uint8Array(string.length);
    for (var i = 0, l = string.length; i < l; i++) {
        array[i] = string.charCodeAt(i);
    }
    return array.buffer;
}

// Nordic UART Service
var SERVICE_UUID = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
var TX_UUID = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
var RX_UUID = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

var app = {
    // Application Constructor
    initialize: function() {
        this.bindEvents();
    },
    bindEvents: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
        sendButton.addEventListener('touchstart', this.updateCharacteristicValue, false);
        
        // 添加新按钮的事件监听器
        document.getElementById('notifyButton').addEventListener('touchstart', this.sendNotificationMessage, false);
        document.getElementById('broadcastButton').addEventListener('touchstart', this.broadcastMessage, false);
    },
    onDeviceReady: function() {
        var property = blePeripheral.properties;
        var permission = blePeripheral.permissions;

        blePeripheral.onWriteRequest(app.didReceiveWriteRequest);
        blePeripheral.onBluetoothStateChange(app.onBluetoothStateChange);

        // 2 different ways to create the service: API calls or JSON
        //app.createService();
        app.createServiceJSON();

    },
    createService: function() {
        // https://learn.adafruit.com/introducing-the-adafruit-bluefruit-le-uart-friend/uart-service
        // Characteristic names are assigned from the point of view of the Central device

        var property = blePeripheral.properties;
        var permission = blePeripheral.permissions;

        Promise.all([
            blePeripheral.createService(SERVICE_UUID),
            blePeripheral.addCharacteristic(SERVICE_UUID, TX_UUID, property.WRITE, permission.WRITEABLE),
            blePeripheral.addCharacteristic(SERVICE_UUID, RX_UUID, property.READ | property.NOTIFY, permission.READABLE),
            blePeripheral.publishService(SERVICE_UUID),
            blePeripheral.startAdvertising(SERVICE_UUID, 'UART')
        ]).then(
            function() { console.log ('Created UART Service'); },
            app.onError
        );

        blePeripheral.onWriteRequest(app.didReceiveWriteRequest);
    },
    createServiceJSON: function() {
        // https://learn.adafruit.com/introducing-the-adafruit-bluefruit-le-uart-friend/uart-service
        // Characteristic names are assigned from the point of view of the Central device

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
                            value: 'Transmit'
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
                            value: 'Receive'
                        }
                    ]
                }
            ]
        };

        Promise.all([
            blePeripheral.createServiceFromJSON(uartService),
            blePeripheral.startAdvertising(uartService.uuid, 'UART')
        ]).then(
            function() { console.log ('Created UART Service'); },
            app.onError
        );
    },
    updateCharacteristicValue: function() {
        var input = document.querySelector('input');
        var bytes = stringToBytes(input.value);

        var success = function() {
            outputDiv.innerHTML += messageInput.value + '<br/>';
            console.log('Updated RX value to ' + input.value);
        };
        var failure = function() {
            console.log('Error updating RX value.');
        };

        blePeripheral.setCharacteristicValue(SERVICE_UUID, RX_UUID, bytes).
            then(success, failure);

    },
    
    // 新增：使用通知功能发送消息
    sendNotificationMessage: function() {
        var input = document.querySelector('input');
        var bytes = stringToBytes(input.value);
        
        // 使用新的通知方法发送消息
        blePeripheral.notifyCharacteristicValue(SERVICE_UUID, RX_UUID, bytes)
            .then(function(result) {
                outputDiv.innerHTML += '<strong>[通知已发送]</strong> ' + input.value + '<br/>';
                console.log('Notification sent successfully:', result);
            })
            .catch(function(error) {
                outputDiv.innerHTML += '<span style="color: red;">[通知发送失败]</span> ' + error + '<br/>';
                console.error('Failed to send notification:', error);
            });
    },
    
    // 新增：广播消息给所有连接的设备
    broadcastMessage: function() {
        var input = document.querySelector('input');
        var bytes = stringToBytes(input.value);
        
        blePeripheral.notifyAllCentrals(SERVICE_UUID, RX_UUID, bytes)
            .then(function(result) {
                outputDiv.innerHTML += '<strong>[广播已发送]</strong> ' + input.value + ' (发送给 ' + result.connectedCentralsCount + ' 个设备)<br/>';
                console.log('Broadcast sent successfully:', result);
            })
            .catch(function(error) {
                outputDiv.innerHTML += '<span style="color: red;">[广播发送失败]</span> ' + error + '<br/>';
                console.error('Failed to broadcast message:', error);
            });
    },
    didReceiveWriteRequest: function(request) {
        var message = bytesToString(request.value);
        console.log(message);
        // warning: message should be escaped to avoid javascript injection
        outputDiv.innerHTML += '<i>' + message + '</i><br/>';
    },
    onBluetoothStateChange: function(data) {
        console.log('Bluetooth State Changed:', data);
        
        if (typeof data === 'string') {
            // 蓝牙适配器状态变化
            outputDiv.innerHTML += 'Bluetooth is ' + data + '<br/>';
        } else if (data && data.type === 'connection') {
            // 设备连接状态变化
            outputDiv.innerHTML += 'Device ' + data.device + ' is ' + data.state + '<br/>';
        }
    }
};

app.initialize();

import QtQuick
import QtQml
import "./services" as Services

Item {
    Component.onCompleted: {
        console.log("Shell startet")
        Services.NetworkService.scan()
    }

    Connections {
        target: Services.NetworkService
        function onWifiEnabledChanged() {
            console.log("wifiEnabled:", Services.NetworkService.wifiEnabled)
        }
        function onConnectedChanged() {
            console.log("connected:", Services.NetworkService.connected, "ssid:", Services.NetworkService.ssid)
        }
        function onEthernetConnectedChanged() {
            console.log("ethernetConnected:", Services.NetworkService.ethernetConnected, "name:", Services.NetworkService.ethernetName)
        }
        function onNetworksChanged() {
            console.log("networks found:", Services.NetworkService.networks.length)
            Services.NetworkService.networks.forEach(n => console.log(" -", n.ssid, n.signal, n.secured))
        }
    }
}

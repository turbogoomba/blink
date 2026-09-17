pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io 

Singleton {
  id: root
  property bool wifiEnable: false
  property bool connected: false
  property string ssid: ""
}

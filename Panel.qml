import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "matteo.pixel-buds"
  ipcTarget: "matteo.pixel-buds"

  readonly property string helper: Qt.resolvedUrl("pixel_buds.py").toString().replace("file://", "")
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property bool budsConnected: {
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      var name = String(device.deviceName || device.name || "").toLowerCase()
      if (device.connected && name.indexOf("buds") !== -1) return true
    }
    return false
  }
  property var state: ({ paired: false, connected: false, name: "Pixel Buds", pbpctrl: false, battery: {}, anc: null, eq: null })
  property bool busy: false

  visible: budsConnected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function act(name, args) {
    if (actionProcess.running) return
    busy = true
    actionProcess.command = [helper, name].concat(args || [])
    actionProcess.running = true
  }

  function setEq(index, value) {
    if (!state.eq || state.eq.length !== 5) return
    var values = state.eq.slice()
    values[index] = Math.round(value * 2) / 2
    state = Object.assign({}, state, { eq: values })
    act("set-eq", values.map(String))
  }

  onOpenedChanged: if (opened) refresh()
  onBudsConnectedChanged: {
    if (budsConnected) refresh()
    else close()
  }

  Process {
    id: statusProcess
    command: [root.helper, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.state = JSON.parse(text) } catch (e) {}
      }
    }
  }

  Process {
    id: actionProcess
    onExited: {
      root.busy = false
      refreshDelay.restart()
    }
  }

  Timer {
    id: refreshDelay
    interval: 700
    onTriggered: root.refresh()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱡒"
    active: root.state.connected
    tooltipText: root.state.name + (root.state.connected ? " connected" : " disconnected")
    onPressed: root.toggle()
  }

  KeyboardPanel {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(360))
    contentHeight: fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Column {
          width: parent.width
          spacing: Style.space(2)
          Text {
            width: parent.width
            text: root.state.name
            color: root.foreground
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader { text: "BATTERY"; foreground: root.foreground; fontFamily: root.fontFamily }

        Row {
          spacing: Style.space(24)
          Repeater {
            model: [
              { label: "Left", value: root.state.battery.left },
              { label: "Right", value: root.state.battery.right },
              { label: "Case", value: root.state.battery.case }
            ]
            Column {
              required property var modelData
              visible: modelData.value !== undefined && modelData.value !== null
              spacing: Style.space(2)
              Text {
                text: modelData.label
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                text: modelData.value + "%"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
            }
          }
        }

        Button {
          visible: !root.state.pbpctrl
          text: "Install pbpctrl-git"
          enabled: !root.busy
          foreground: root.foreground
          fontFamily: root.fontFamily
          focusable: true
          bordered: true
          onClicked: root.act("install-pbpctrl")
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader { text: "NOISE CONTROL"; foreground: root.foreground; fontFamily: root.fontFamily }

        Row {
          spacing: Style.space(6)
          Repeater {
            model: [
              { label: "Off", value: "off" },
              { label: "ANC", value: "active" },
              { label: "Aware", value: "aware" },
              { label: "Adaptive", value: "adaptive" }
            ]
            Button {
              required property var modelData
              text: modelData.label
              selected: root.state.anc === modelData.value
              enabled: root.state.pbpctrl && root.state.connected && root.state.anc !== null && !root.busy
              foreground: root.foreground
              fontFamily: root.fontFamily
              focusable: true
              bordered: true
              onClicked: root.act("anc-" + modelData.value)
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader { text: "EQUALIZER"; foreground: root.foreground; fontFamily: root.fontFamily }

        Repeater {
          model: ["Low bass", "Bass", "Mid", "Treble", "Upper treble"]
          Item {
            required property int index
            required property string modelData
            width: content.width
            implicitHeight: Style.space(30)

            Text {
              width: Style.space(82)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: modelData
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            PanelSlider {
              id: eqSlider
              anchors.left: parent.left
              anchors.leftMargin: Style.space(90)
              anchors.right: eqValue.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              bar: root.bar
              minimum: -6
              maximum: 6
              step: 0.5
              value: root.state.eq ? root.state.eq[index] : 0
              enabled: root.state.eq !== null && !root.busy
              opacity: enabled ? 1 : 0.5
              tickCount: 13
              onReleased: function(value) { root.setEq(index, value) }
            }

            Text {
              id: eqValue
              width: Style.space(32)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignRight
              text: Math.round((eqSlider.dragging ? eqSlider.liveValue : eqSlider.value) * 2) / 2 + " dB"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}

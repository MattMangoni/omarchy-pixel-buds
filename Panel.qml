import QtQuick
import Quickshell
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
  property var state: ({ paired: false, connected: false, name: "Pixel Buds", pbpctrl: false, battery: {}, anc: null })
  property bool busy: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function act(name) {
    if (actionProcess.running) return
    busy = true
    actionProcess.command = [helper, name]
    actionProcess.running = true
  }

  onOpenedChanged: if (opened) refresh()

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
    text: "󰋋"
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

        Row {
          width: parent.width
          spacing: Style.space(10)

          Column {
            width: parent.width - connection.width - parent.spacing
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
            Text {
              text: !root.state.paired ? "NOT PAIRED" : root.state.connected ? "CONNECTED" : "DISCONNECTED"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }

          Button {
            id: connection
            text: root.state.connected ? "Disconnect" : "Connect"
            enabled: root.state.paired && !root.busy
            foreground: root.foreground
            fontFamily: root.fontFamily
            focusable: true
            bordered: true
            onClicked: root.act(root.state.connected ? "disconnect" : "connect")
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

        Text {
          visible: !root.state.connected
          text: "Connect the earbuds to read battery and noise control"
          color: Qt.darker(root.foreground, 1.4)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
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
      }
    }
  }
}

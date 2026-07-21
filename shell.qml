// File: shell.qml
//@ pragma UseQApplication
import QtQuick 2.15
import Quickshell
import Quickshell.Wayland
import "./modules/layout"
import "./modules/widgets"
import "./modules/launcher"

ShellRoot {
  id: root

  // Edge assets (adjust to your paths)
  property url topSrc:    Qt.resolvedUrl("./assets/top.png")
  property url bottomSrc: Qt.resolvedUrl("./assets/bottom.png")
  property url leftSrc:   Qt.resolvedUrl("./assets/left.png")
  property url rightSrc:  Qt.resolvedUrl("./assets/right.png")

  // 1) Edge reservation + (optional) drawing
  EdgeOverlayLayout {
    id: edgeLayout
    thickness: 64
    enableTop: true; enableBottom: true; enableLeft: true; enableRight: true
    topSource: topSrc; bottomSource: bottomSrc; leftSource: leftSrc; rightSource: rightSrc
    drawContent: true
  }

  // 2) Overlay (HUD + panel inside HUD rectangle)
  PanelWindow {

    property int leftMargin:-56

    id: hudWin
    color: "transparent"//'#38ffffff'
    mask: Region {}                     // click-through
    // Pick your edge and size; example shows right edge full-height.
    anchors { left: true; top: true; bottom: true }
    implicitWidth: 880
    implicitHeight: 1500
    // CRITICAL: do not reserve; overlap other reserved panels
    exclusiveZone: 0 
    exclusionMode: ExclusionMode.Ignore
    // Draw above normal windows
    aboveWindows: true
    // Ensure we sit in the overlay layer (above Top where your borders live)
    Component.onCompleted: {
    if (hudWin.WlrLayershell) hudWin.WlrLayershell.layer = WlrLayer.Overlay
    }
    margins{ left:leftMargin;bottom:14}
    
    ChatGPTHud {
      id: hud
      anchors.fill: parent
      panelWindow: hudWin
      focus: false
      command: "/home/nihil/Extra/Chatgpt-PyGObject/chatgpt-wrapper"
      // Geometry (tune as needed)
      s: 8
      rectW: 808
      rectH: 1300
      shiftX: 380
    }
  }

  PanelWindow {
    property int rightMargin: -72
    property var maskRegion: Region {}
    property bool clickThrough: true   
    id: hudLock
    color: "transparent"
    anchors { right: true; top: true; bottom: true }
    implicitWidth: 260
    implicitHeight: 600
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    Component.onCompleted: {
      if (hudLock.WlrLayershell) hudLock.WlrLayershell.layer = WlrLayer.Overlay 
    }
    margins { right: rightMargin; bottom: 14 }

    

    LockHud {                 // <-- usa il nuovo file
      id: lockHud
      anchors.fill: parent
      panelWindow: hudLock            // <-- usa il suo panel
      s: 8
      rectW: 180
      rectH: 600
      shiftX: 80        
      initX: 214      // <-- offset iniziale per tenerlo fuori schermo     
    }
    
    mask : clickThrough ? maskRegion : null  // <-- usa la proprietà clickThrough di LockHudp         

  }

  PanelWindow {
    id: launcherWin
    color: "transparent"
    anchors { right: true; top: true; bottom: true; left: true }
    implicitWidth: 1000
    implicitHeight: 800
    exclusiveZone: 0
    mask: Region {}
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    LauncherHud {
      id: launcherHud
      anchors.fill: parent
      panelWindow: launcherWin
      s: 8
      gap: 12
      rectW: launcherWin.implicitWidth
      rectH: launcherWin.implicitHeight
    }
  }



}

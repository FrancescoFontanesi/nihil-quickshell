import QtQuick 2.12
import Quickshell
import Quickshell.Io
import QtQml 2.15
 
 

Item {
    id: root
    focus: false

    // ---- Geometry / style ----
    property int  s: 10
    property int  rectW: 300
    property int  rectH: 80
    property int  topMargin: 24
    property color hudColor:    "#ffffff"
    property color hudColorDim: "#80ffffff"
    property bool  showLines: true



    // ---- Icon ----
    property url iconSource: Qt.resolvedUrl("../../assets/brightness.png")   
    property int iconSize: 24
    property color iconTint: "#ffffff"
    property int percent: 0   // 0-100

    readonly property int cx:  Math.round((width  - rectW) / 2) 
    readonly property int yTop: topMargin

    width:  rectW + 2*s
    height: rectH + topMargin + s + (iconSource==""?0:iconSize+8)

    readonly property string brightnessUrl: Qt.resolvedUrl("../../tmp/brightness_percent")
    readonly property string brightnessFile: brightnessUrl.startsWith("file://")
        ? decodeURIComponent(brightnessUrl.slice("file://".length))
        : brightnessUrl


    function updatePercent(rawValue) {
        const value = parseInt(String(rawValue).trim(), 10)
        if (!isNaN(value))
            root.percent = Math.max(0, Math.min(100, value))
    }

    FileView {
        id: brightnessView
        path: root.brightnessFile
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.updatePercent(text())
    }



    // ---- Nodes + Canvas frame ----
    Repeater {
        id: nodes
        model: 4
        delegate: Rectangle {
            width: s; height: s; radius: 0; color: hudColor
            property bool isBottom: index >= 2
            property bool isRight : (index % 2) === 1
            x: root.cx + (isRight ? (rectW - s) : 0)
            y: root.yTop + (isBottom ? (rectH - s) : 0)
            onXChanged: lines.requestPaint()
            onYChanged: lines.requestPaint()
        }
    }
    Canvas {
        id: lines
        anchors.fill: parent
        visible: showLines
        onPaint: {
            var a = nodes.itemAt(0), b = nodes.itemAt(1), c = nodes.itemAt(3), d = nodes.itemAt(2);
            if (!a || !b || !c || !d) return;
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.lineWidth = 2; ctx.strokeStyle = hudColorDim;
            function mid(it){ return it.mapToItem(lines, it.width/2, it.height/2); }
            var pa = mid(a), pb = mid(b), pc = mid(c), pd = mid(d);
            ctx.beginPath(); ctx.moveTo(pa.x, pa.y); ctx.lineTo(pb.x, pb.y);
            ctx.lineTo(pc.x, pc.y); ctx.lineTo(pd.x, pd.y);
            ctx.closePath(); ctx.stroke();
        }
    }

    // ---- Inner frame + fill ----
    Rectangle {
        id: frame
        x: root.cx + s + 8
        y: root.yTop + s + 8
        width:  rectW - (2*s + 16)
        height: rectH - (2*s + 16)
        radius: 8
        color: 'transparent'
        border.color: "#ffffff"
        border.width: 2

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            height: Math.max(parent.height - (anchors.verticalCenterOffset * 2), 4)
            width: Math.max(0, Math.round((parent.width - anchors.leftMargin - anchors.rightMargin) * root.percent / 100))
            radius: 8
            color: "#ffffff"
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }

    // ---- Icon (optional) ----
    Image {
        visible: iconSource !== ""
        source: iconSource
        width: iconSize; height: iconSize
        x: frame.x + 100
        y: frame.y + frame.height + 8
        fillMode: Image.PreserveAspectFit
        layer.enabled: true
        layer.smooth: true
    }

   
}

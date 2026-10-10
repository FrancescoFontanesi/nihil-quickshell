import "../common"
import QtQuick 2.12
import Quickshell.Services.Pipewire

HudLevelBar {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    percent: sink && sink.audio
        ? Math.max(0, Math.min(100, Math.round(sink.audio.volume * 100)))
        : 0
    property bool muted: !!(sink && sink.audio && sink.audio.muted)

    iconSource: Qt.resolvedUrl("../../assets/volume.png")
    fillColor: muted ? Hud.alert : Hud.fg

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}

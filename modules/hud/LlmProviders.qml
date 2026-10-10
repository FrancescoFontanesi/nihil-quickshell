import "../common"
import QtQuick

// Provider rail (always shown while open) and provider editor (CFG toggles it).
// All state and commands come from LlmModel; this file is the view only.
Item {
    id: view
    required property var llm
    property bool open: false
    property bool editorOpen: false
    property string armedRemove: ""          // provider whose REMOVE is waiting for CONFIRM
    readonly property Item rail: railPlate
    readonly property Item editor: editorPlate
    readonly property bool needsKeyboard: open && editorOpen

    width: 48 + (editorPlate.width > 0 ? 4 + editorPlate.width : 0)
    height: Math.max(railPlate.height, editorPlate.height)
    opacity: open ? 1 : 0
    Behavior on opacity { CnAnim {} }
    visible: opacity > 0
    onOpenChanged: if (!open) editorOpen = false

    function submit() {
        if (!addButton.enabled) return
        if (llm.add(nameField.text, urlField.text)) {
            nameField.text = ""
            urlField.text = ""
        }
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: view.armedRemove = ""
    }

    // ======== RAIL ========
    Rectangle {
        id: railPlate
        x: 0
        y: 0
        width: 48
        height: railColumn.implicitHeight + 16
        color: "#d8000000"
        border.width: 1
        border.color: Hud.borderPassive

        Column {
            id: railColumn
            x: 6
            y: 8
            spacing: 4

            Text {
                width: 36
                height: 14
                horizontalAlignment: Text.AlignHCenter
                text: "LLM"
                color: Hud.cnTextMuted
                font.family: Hud.mono
                font.pixelSize: 9
                font.letterSpacing: 1.0
            }

            Repeater {
                model: view.llm.names

                Item {
                    id: tile
                    required property string modelData
                    readonly property bool active: modelData === view.llm.active
                    readonly property bool hovered: tileMouse.containsMouse
                    width: 36
                    height: 28

                    CnCut {
                        anchors.fill: parent
                        br: 4
                        fill: tile.active ? Hud.cnInk : "transparent"
                        edge: tile.active || tile.hovered ? Hud.cnInk : Hud.cnBorderPassive
                    }

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: view.llm.code(tile.modelData)
                        color: tile.active ? Hud.cnGround : Hud.cnInk
                        font.family: Hud.mono
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.letterSpacing: 0.6
                    }

                    // Default-provider marker.
                    Rectangle {
                        visible: tile.modelData === view.llm.defaultProvider
                        x: 3
                        y: 3
                        width: 4
                        height: 4
                        color: tile.active ? Hud.cnGround : Hud.cnInk
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.llm.select(tile.modelData)
                    }
                }
            }

            Rectangle {
                width: 36
                height: 1
                color: Hud.cnBorderPassive
            }

            Item {
                id: cfgTile
                readonly property bool hovered: cfgMouse.containsMouse
                width: 36
                height: 28

                CnCut {
                    anchors.fill: parent
                    br: 4
                    fill: view.editorOpen ? Hud.cnInk : "transparent"
                    edge: view.editorOpen || cfgTile.hovered ? Hud.cnInk : Hud.cnBorderPassive
                }

                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "CFG"
                    color: view.editorOpen ? Hud.cnGround : Hud.cnInk
                    font.family: Hud.mono
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6
                }

                MouseArea {
                    id: cfgMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.editorOpen = !view.editorOpen
                }
            }
        }
    }

    // ======== EDITOR ========
    Rectangle {
        id: editorPlate
        x: 52
        y: 0
        width: view.editorOpen ? 280 : 0
        Behavior on width { CnAnim { duration: Hud.durMedium } }
        visible: width > 0
        clip: true
        color: "#d8000000"
        border.width: 1
        border.color: Hud.borderPassive
        height: content.height + 14

        // Fixed width: no reflow while the plate animates its width.
        Item {
            id: content
            x: 14
            width: 252
            height: addButton.y + addButton.height

            Text {
                y: 12
                text: "LLM · PROVIDERS"
                color: Hud.cnTextMuted
                font.family: Hud.mono
                font.pixelSize: 9
                font.letterSpacing: 1.0
            }

            Text {
                id: title
                y: 24
                text: "PROVIDERS"
                color: Hud.cnInk
                font.family: Hud.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            CnButton {
                anchors.right: parent.right
                anchors.verticalCenter: title.verticalCenter
                width: 22
                height: 22
                cut: 4
                text: "✕"
                textSize: 11
                onClicked: view.editorOpen = false
            }

            Item {
                id: statusRow
                y: 48
                width: 252
                height: 14

                CnStatus {
                    id: statusChip
                    anchors.verticalCenter: parent.verticalCenter
                    code: !view.llm.running ? "OFF" : "NOM"
                }

                Text {
                    x: statusChip.width + 8
                    width: statusRow.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: !view.llm.running ? "WRAPPER NOT RUNNING" : "ACTIVE · " + view.llm.active.toUpperCase()
                    color: Hud.cnTextSecondary
                    font.family: Hud.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.54
                }
            }

            Rectangle {
                y: 70
                width: 252
                height: 1
                color: Hud.cnBorderPassive
            }

            Column {
                id: list
                y: 78
                width: 252
                spacing: 4

                Repeater {
                    model: view.llm.names

                    Item {
                        id: row
                        required property string modelData
                        readonly property bool active: modelData === view.llm.active
                        readonly property bool isDefault: modelData === view.llm.defaultProvider
                        readonly property color rowInk: active ? Hud.cnGround : Hud.cnInk
                        readonly property color rowMuted: active ? Hud.cnGround : Hud.cnTextMuted
                        readonly property bool showActions: hover.hovered
                        readonly property real labelWidth: showActions ? width - 46 - actions.width - 18 : width - 86   // hovered: URL hidden, actions on the right
                        width: 252
                        height: 40

                        HoverHandler { id: hover }

                        CnCut {
                            anchors.fill: parent
                            br: 6
                            fill: row.active ? Hud.cnInk : "transparent"
                            edge: row.active || hover.hovered ? Hud.cnInk : Hud.cnBorderPassive
                        }

                        Text {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.llm.code(row.modelData)
                            color: row.rowInk
                            font.family: Hud.mono
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }

                        Text {
                            x: 46
                            y: row.showActions ? (row.height - height) / 2 : 6
                            width: row.labelWidth
                            text: row.modelData
                            color: row.rowInk
                            font.family: Hud.font
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: !row.showActions
                            x: 46
                            y: 22
                            width: row.labelWidth
                            text: view.llm.providers[row.modelData]
                            color: row.rowMuted
                            font.family: Hud.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: row.isDefault && !hover.hovered
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DEF"
                            color: row.rowInk
                            font.family: Hud.mono
                            font.pixelSize: 9
                            font.letterSpacing: 0.9
                        }

                        // Below the buttons: a click anywhere else selects the provider.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.llm.select(row.modelData)
                        }

                        Row {
                            id: actions
                            visible: row.showActions
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 20
                            spacing: 4

                            CnButton {
                                visible: !row.isDefault
                                height: 20
                                text: "DEFAULT"
                                textSize: 9
                                onClicked: view.llm.setDefault(row.modelData)
                            }

                            CnButton {
                                height: 20
                                variant: "critical"
                                text: view.armedRemove === row.modelData ? "CONFIRM" : "REMOVE"
                                textSize: 9
                                enabled: view.llm.names.length > 1
                                onClicked: {
                                    if (view.armedRemove === row.modelData) {
                                        armTimer.stop()
                                        view.armedRemove = ""
                                        view.llm.remove(row.modelData)
                                    } else {
                                        view.armedRemove = row.modelData
                                        armTimer.restart()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: addRule
                y: list.y + list.height + 10
                width: 252
                height: 1
                color: Hud.cnBorderPassive
            }

            Text {
                id: addLabel
                y: addRule.y + addRule.height + 10
                text: "ADD · PROVIDER"
                color: Hud.cnTextMuted
                font.family: Hud.mono
                font.pixelSize: 9
                font.letterSpacing: 1.0
            }

            CnInput {
                id: nameField
                y: addLabel.y + addLabel.height + 10
                width: 252
                height: implicitHeight
                label: "NAME"
                error: nameField.text !== "" ? view.llm.nameError(nameField.text) : ""
                onAccepted: view.submit()
                onEscaped: view.editorOpen = false
            }

            CnInput {
                id: urlField
                y: nameField.y + nameField.height + 8
                width: 252
                height: implicitHeight
                label: "URL"
                error: urlField.text !== "" ? view.llm.urlError(urlField.text) : ""
                onAccepted: view.submit()
                onEscaped: view.editorOpen = false
            }

            CnButton {
                id: addButton
                y: urlField.y + urlField.height + 10
                width: 252
                height: 28
                variant: "primary"
                text: "ADD"
                textSize: 10
                enabled: nameField.text !== "" && urlField.text !== "" && nameField.error === "" && urlField.error === ""
                onClicked: view.submit()
            }
        }
    }
}

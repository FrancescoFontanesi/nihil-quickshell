import "../common"
import QtQuick
import QtQuick.Effects

// Provider tab on the HUD frame's top edge + the provider panel drawn over the wrapper.
Item {
    id: view
    required property var llm
    property bool hudOpen: false
    property rect frame
    property int nodeSize: 8
    property bool panelOpen: false
    property string armedRemove: ""
    readonly property Item tab: tabItem
    readonly property Item panel: panelItem
    readonly property bool needsKeyboard: hudOpen && panelOpen
    function focusPanel() { scope.forceActiveFocus() }
    onHudOpenChanged: if (!hudOpen) panelOpen = false

    function submit() {
        if (llm.add(nameField.text, urlField.text)) {
            nameField.text = ""
            urlField.text = ""
        }
    }

    // Icon: grayscale favicon when one is cached, else the outlined first letter.
    component ProviderIcon: Item {
        id: icon
        property string source
        property string fallback

        Image {
            id: img
            anchors.fill: parent
            visible: false
            source: icon.source
            sourceSize: Qt.size(icon.width * 2, icon.height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            saturation: -1.0
            visible: icon.source !== "" && img.status !== Image.Error
        }
        CnCut {
            anchors.fill: parent
            visible: !(icon.source !== "" && img.status !== Image.Error)
            br: 4
            edge: Hud.cnBorderActive
        }
        Text {
            anchors.centerIn: parent
            visible: !(icon.source !== "" && img.status !== Image.Error)
            text: icon.fallback.charAt(0).toUpperCase()
            color: Hud.cnTextSecondary
            font.family: Hud.mono
            font.pixelSize: Math.round(icon.width * 0.45)
        }
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: view.armedRemove = ""
    }

    // ======== TAB ========
    Item {
        id: tabItem
        height: 24
        width: tabRow.implicitWidth + 20
        x: view.frame.x + Math.round((view.frame.width - width) / 2)
        y: view.frame.y - 12
        opacity: view.hudOpen ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { CnAnim {} }

        CnCut {
            anchors.fill: parent
            br: 6
            fill: view.panelOpen ? Hud.cnInk : Hud.cnGround
            edge: view.panelOpen || tabMouse.containsMouse ? Hud.cnInk : Hud.cnBorderActive
        }
        Row {
            id: tabRow
            anchors.centerIn: parent
            spacing: 6
            ProviderIcon {
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                source: view.llm.iconFor(view.llm.active)
                fallback: view.llm.active
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 160)
                text: view.llm.active !== "" ? view.llm.active.toUpperCase() : "NO PROVIDER"
                elide: Text.ElideRight
                color: view.panelOpen ? Hud.cnGround : Hud.cnInk
                font.family: Hud.mono
                font.pixelSize: 9
                font.letterSpacing: 1.0
            }
        }
        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.panelOpen = !view.panelOpen
        }
    }

    // ======== PANEL ========
    Item {
        id: panelItem
        clip: true
        x: view.frame.x + view.nodeSize
        y: view.frame.y + view.nodeSize
        width: view.frame.width - 2 * view.nodeSize
        height: view.hudOpen && view.panelOpen ? view.frame.height - 2 * view.nodeSize : 0
        visible: height > 0
        Behavior on height { CnAnim { duration: Hud.durMedium } }

        Rectangle {
            anchors.fill: parent
            color: Hud.cnGround
            border.width: 1
            border.color: Hud.borderPassive
        }

        FocusScope {
            id: scope
            anchors.fill: parent
            Keys.onEscapePressed: view.panelOpen = false

            Item {
                id: content
                x: 32
                y: 0
                width: view.frame.width - 2 * view.nodeSize - 64

                Text {
                    y: 28
                    text: "LLM · PROVIDERS"
                    color: Hud.cnTextMuted
                    font.family: Hud.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.0
                }
                Text {
                    id: title
                    y: 42
                    text: "PROVIDERS"
                    color: Hud.cnInk
                    font.family: Hud.font
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                }
                CnButton {
                    x: content.width - width
                    anchors.verticalCenter: title.verticalCenter
                    width: 22
                    height: 22
                    cut: 4
                    textSize: 11
                    text: "✕"
                    onClicked: view.panelOpen = false
                }

                // Status row
                CnStatus {
                    id: statusChip
                    y: 72
                    code: view.llm.running ? "NOM" : "OFF"
                }
                Text {
                    anchors.left: statusChip.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: statusChip.verticalCenter
                    text: view.llm.running
                          ? "ACTIVE · " + view.llm.active.toUpperCase() + "    DEFAULT · " + view.llm.defaultProvider.toUpperCase()
                          : "WRAPPER NOT RUNNING"
                    color: Hud.cnTextSecondary
                    font.family: Hud.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.54
                }

                Rectangle {
                    y: 98
                    width: content.width
                    height: 1
                    color: Hud.cnBorderPassive
                }

                // Provider cards
                Grid {
                    id: cards
                    y: 114
                    width: content.width
                    columns: 3
                    spacing: 12
                    Repeater {
                        model: view.llm.names
                        delegate: Item {
                            id: card
                            required property string modelData
                            readonly property string provider: modelData
                            readonly property bool active: provider === view.llm.active
                            readonly property bool isDefault: provider === view.llm.defaultProvider
                            readonly property color rowInk: active ? Hud.cnGround : Hud.cnInk
                            readonly property color rowMuted: active ? Hud.cnGround : Hud.cnTextMuted

                            width: (content.width - 24) / 3
                            height: 132

                            HoverHandler { id: hover }

                            CnCut {
                                anchors.fill: parent
                                br: 8
                                fill: card.active ? Hud.cnInk : "transparent"
                                edge: card.active || hover.hovered ? Hud.cnInk : Hud.cnBorderPassive
                            }
                            ProviderIcon {
                                x: 16
                                y: 16
                                width: 40
                                height: 40
                                source: view.llm.iconFor(card.provider)
                                fallback: card.provider
                            }
                            Item {
                                visible: card.isDefault
                                x: card.width - 16 - width
                                y: 16
                                height: 18
                                width: tagLabel.implicitWidth + 12
                                CnCut {
                                    anchors.fill: parent
                                    br: 4
                                    fill: card.active ? Hud.cnGround : Hud.cnInk
                                    edge: "transparent"
                                }
                                Text {
                                    id: tagLabel
                                    anchors.centerIn: parent
                                    text: "DEF"
                                    color: card.active ? Hud.cnInk : Hud.cnGround
                                    font.family: Hud.mono
                                    font.pixelSize: 9
                                    font.letterSpacing: 0.9
                                }
                            }
                            Text {
                                x: 16
                                y: 66
                                width: card.width - 32
                                text: card.provider
                                elide: Text.ElideRight
                                color: card.rowInk
                                font.family: Hud.font
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                x: 16
                                y: 88
                                width: card.width - 32
                                text: view.llm.providers[card.provider] || ""
                                elide: Text.ElideRight
                                color: card.rowMuted
                                font.family: Hud.mono
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.llm.select(card.provider)
                                    view.panelOpen = false
                                }
                            }
                            Row {
                                x: 16
                                y: 104
                                spacing: 4
                                visible: hover.hovered
                                CnButton {
                                    visible: !card.isDefault
                                    height: 20
                                    textSize: 9
                                    text: "DEFAULT"
                                    onClicked: view.llm.setDefault(card.provider)
                                }
                                CnButton {
                                    height: 20
                                    textSize: 9
                                    variant: "critical"
                                    text: view.armedRemove === card.provider ? "CONFIRM" : "REMOVE"
                                    enabled: view.llm.names.length > 1
                                    onClicked: {
                                        if (view.armedRemove === card.provider) {
                                            armTimer.stop()
                                            view.armedRemove = ""
                                            view.llm.remove(card.provider)
                                        } else {
                                            view.armedRemove = card.provider
                                            armTimer.restart()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Add section
                Rectangle {
                    id: addRule
                    y: cards.y + cards.height + 24
                    width: content.width
                    height: 1
                    color: Hud.cnBorderPassive
                }
                Text {
                    id: addLabel
                    y: addRule.y + 13
                    text: "ADD · PROVIDER"
                    color: Hud.cnTextMuted
                    font.family: Hud.mono
                    font.pixelSize: 9
                    font.letterSpacing: 1.0
                }
                Row {
                    id: fields
                    y: addLabel.y + addLabel.height + 10
                    width: content.width
                    spacing: 12
                    CnInput {
                        id: nameField
                        label: "NAME"
                        width: (content.width - 12) / 2
                        height: implicitHeight
                        error: text !== "" ? view.llm.nameError(text) : ""
                        onAccepted: if (addBtn.enabled) view.submit()
                        onEscaped: view.panelOpen = false
                    }
                    CnInput {
                        id: urlField
                        label: "URL"
                        width: (content.width - 12) / 2
                        height: implicitHeight
                        error: text !== "" ? view.llm.urlError(text) : ""
                        onAccepted: if (addBtn.enabled) view.submit()
                        onEscaped: view.panelOpen = false
                    }
                }
                CnButton {
                    id: addBtn
                    x: content.width - width
                    y: fields.y + fields.height + 12
                    variant: "primary"
                    text: "ADD"
                    width: 160
                    height: 28
                    textSize: 10
                    enabled: nameField.text !== "" && urlField.text !== ""
                             && nameField.error === "" && urlField.error === ""
                    onClicked: view.submit()
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                text: "ESC · CLOSE    CLICK · SWITCH"
                color: Hud.cnTextMuted
                font.family: Hud.mono
                font.pixelSize: 9
                font.letterSpacing: 1.0
            }
        }
    }
}

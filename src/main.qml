import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.DialogWindow {
    id: root

    title: qsTr("Nitrux PolicyKit Agent")
    readonly property int dialogWidth: Math.min(Screen.desktopAvailableWidth, Maui.Style.units.gridUnit * 24)
    readonly property int dialogHeight: Math.min(Screen.desktopAvailableHeight, contentColumn.implicitHeight + page.footBar.implicitHeight)
    width: dialogWidth
    minimumWidth: dialogWidth
    maximumWidth: dialogWidth
    height: dialogHeight
    minimumHeight: dialogHeight
    maximumHeight: dialogHeight
    visible: agent.active
    color: "transparent"
    background: null
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint

    Maui.WindowBlur {
        view: root
        geometry: Qt.rect(0, 0, root.width, root.height)
        windowRadius: Maui.Style.radiusV
        enabled: true
    }

    page.background: Rectangle {
        anchors.fill: parent
        color: Maui.Theme.backgroundColor
        opacity: 0.76
        radius: Maui.Style.radiusV
        border.color: Qt.rgba(1, 1, 1, 0)
        border.width: 1
    }

    property var selectedIdentity: agent.selectedIdentity >= 0 && agent.selectedIdentity < agent.identities.length
        ? agent.identities[agent.selectedIdentity] : null
    property string displayedCommand: agent.command.length > 0 ? agent.command : commandFromMessage(agent.message)
    property int timeoutSeconds: 30
    property int remainingSeconds: timeoutSeconds
    property bool showDetails: false

    readonly property bool pinRequested: !agent.echo && /\bpin\b/i.test(agent.prompt)
    readonly property bool scanning: !agent.prompt && /^(please\s+)?(place|swipe|press|touch|scan)\b/i.test(agent.info.trim())
    readonly property bool fingerprintMismatch: agent.error.trim() === "Failed to match fingerprint"

    function resetTimeout() {
        remainingSeconds = timeoutSeconds
        if (agent.active)
            inactivityTimer.restart()
    }

    function commandFromMessage(message) {
        const match = message.match(/[\u0060'"\u201c\u201d\u2018\u2019]([^\u0060'"\u201c\u201d\u2018\u2019]+)[\u0060'"\u201c\u201d\u2018\u2019]/)
        return match ? match[1] : ""
    }

    function submitResponse() {
        if (passwordField.canSubmit) {
            agent.submitResponse(passwordField.text)
            passwordField.clear()
        }
    }

    Timer {
        id: inactivityTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (!agent.active) {
                stop()
                return
            }
            remainingSeconds -= 1
            if (remainingSeconds <= 0) {
                stop()
                agent.cancel()
            }
        }
    }

    onClosing: function(close) {
        if (agent.active) {
            close.accepted = false
            agent.cancel()
        }
    }

    page.flickable: contentColumn.flickable
    page.headBar.visible: false
    page.footBar.visible: true
    page.footBar.background: null
    page.footBar.preferredHeight: Maui.Style.rowHeightAlt
    page.footBar.topPadding: Maui.Style.defaultPadding
    page.footBar.bottomPadding: Maui.Style.defaultPadding
    page.footBar.forceCenterMiddleContent: true
    page.footBar.middleContent: Item {
        Layout.fillWidth: true
        implicitHeight: actionsRow.implicitHeight

        RowLayout {
            id: actionsRow
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            spacing: Maui.Style.space.small

            Button {
                text: qsTr("Cancel (%1)").arg(root.remainingSeconds)
                onClicked: agent.cancel()
            }

            Button {
                text: qsTr("Authorize")
                enabled: passwordField.canSubmit
                Maui.Controls.status: Maui.Controls.Positive
                onClicked: root.submitResponse()
            }
        }
    }

    Maui.ScrollColumn {
        id: contentColumn
        anchors.fill: parent
        clip: true
        spacing: Maui.Style.space.small

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Authorization Required")
            text2: root.displayedCommand.length > 0
                ? qsTr("Authentication is needed to run the following program as the superuser.")
                : (agent.message || qsTr("Authentication is needed to continue"))
            template.label1.font.pointSize: Maui.Style.defaultFont.pointSize + 2
            template.label1.font.bold: true
            template.label1.color: Maui.Theme.textColor
            template.label1.horizontalAlignment: Text.AlignHCenter
            template.label2.font.pointSize: Maui.Style.defaultFont.pointSize
            template.label2.color: Maui.Theme.textColor
            template.label2.wrapMode: Text.WordWrap
            template.label2.horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1
            implicitHeight: authenticationSection.implicitHeight + Maui.Style.contentMargins * 2

            ColumnLayout {
                id: authenticationSection
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Authentication")
                    text2: qsTr("Enter your credentials to authorize this request.")
                    label2.wrapMode: Text.Wrap
                }

                Maui.IconItem {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 128
                    imageSource: agent.avatarUrl
                    iconSource: ""
                    imageSizeHint: -1
                    fillMode: Image.PreserveAspectCrop
                    maskRadius: Math.min(width, height) / 2
                }

                Label {
                    Layout.fillWidth: true
                    text: root.selectedIdentity ? root.selectedIdentity.label : ""
                    color: Maui.Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                ComboBox {
                    Layout.alignment: Qt.AlignHCenter
                    visible: agent.identities.length > 1
                    Layout.preferredWidth: 220
                    model: agent.identities
                    textRole: "label"
                    currentIndex: agent.selectedIdentity
                    onActivated: {
                        root.resetTimeout()
                        agent.selectIdentity(currentIndex)
                    }
                }

                Maui.TextField {
                    id: passwordField
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Maui.Style.space.medium
                    Layout.preferredWidth: parent.width / 2
                    Layout.maximumWidth: parent.width / 2
                    visible: agent.prompt.length > 0
                    readonly property bool canSubmit: visible && text.length > 0 && acceptableInput
                    // Maui.TextField exposes its inline clear button through rightContent.
                    Binding {
                        target: passwordField.rightContent[0]
                        property: "visible"
                        when: root.pinRequested
                        value: false
                    }
                    horizontalAlignment: root.pinRequested ? TextInput.AlignHCenter : TextInput.AlignLeft
                    validator: root.pinRequested ? pinValidator : null
                    RegularExpressionValidator { id: pinValidator; regularExpression: /[0-9]+/ }
                    inputMethodHints: root.pinRequested ? Qt.ImhDigitsOnly | Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
                    placeholderText: agent.prompt || qsTr("Password")
                    echoMode: agent.echo ? TextInput.Normal : TextInput.Password
                    Maui.Controls.status: agent.error.length > 0 ? Maui.Controls.Negative : Maui.Controls.Normal
                    onTextChanged: root.resetTimeout()
                    onAccepted: root.submitResponse()
                }

                GridLayout {
                    visible: root.pinRequested
                    Layout.alignment: Qt.AlignHCenter
                    columns: 3
                    rowSpacing: Maui.Style.space.small
                    columnSpacing: rowSpacing

                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "✓"]
                        Button {
                            required property string modelData
                            Layout.preferredWidth: Maui.Style.rowHeight * 1.5
                            Layout.preferredHeight: Maui.Style.rowHeight * 1.5
                            icon.name: modelData === "⌫" ? "edit-clear" : ""
                            text: modelData === "⌫" ? "" : modelData
                            Accessible.name: modelData === "✓" ? qsTr("Submit PIN")
                                : modelData === "⌫" ? qsTr("Delete digit") : modelData
                            enabled: modelData !== "✓" || passwordField.canSubmit
                            onClicked: {
                                if (modelData === "✓")
                                    root.submitResponse()
                                else if (modelData === "⌫")
                                    passwordField.text = passwordField.text.slice(0, -1)
                                else
                                    passwordField.text += modelData
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: agent.info.length > 0 || agent.error.length > 0
                    text: root.fingerprintMismatch ? qsTr("Fingerprint did not match.")
                        : agent.error.length > 0 ? agent.error
                        : root.scanning ? qsTr("Place your finger on the sensor.") : agent.info
                    color: agent.error.length > 0 ? Maui.Theme.negativeTextColor : Maui.Theme.linkColor
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Maui.Chip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Maui.Style.space.small
                    visible: root.scanning && !agent.error
                    enabled: false
                    hoverEnabled: false
                    color: Maui.Theme.highlightColor
                    spacing: 0
                    SequentialAnimation on opacity {
                        running: root.scanning && !agent.error && agent.active
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.35; to: 1; duration: 450 }
                        NumberAnimation { from: 1; to: 0.35; duration: 450 }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Maui.Style.contentMargins
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1
            implicitHeight: detailsSection.implicitHeight + Maui.Style.contentMargins * 2

            ColumnLayout {
                id: detailsSection
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Show details")
                    label2.text: qsTr("Show PolicyKit action and vendor information.")
                    label2.wrapMode: Text.Wrap
                    template.content: Switch {
                        checked: root.showDetails
                        onToggled: root.showDetails = checked
                    }
                }

                Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    flat: true
                    visible: root.showDetails
                    label1.text: qsTr("Identity")
                    label2.text: root.selectedIdentity ? root.selectedIdentity.label : ""
                    label2.wrapMode: Text.Wrap
                }

                Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    flat: true
                    visible: root.showDetails
                    label1.text: qsTr("Action ID")
                    label2.text: agent.actionId
                    label2.font.family: Maui.Style.monospacedFont.family
                    label2.wrapMode: Text.Wrap
                }

                Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    flat: true
                    visible: root.showDetails && root.displayedCommand.length > 0
                    label1.text: qsTr("Program")
                    label2.text: root.displayedCommand
                    label2.font.family: Maui.Style.monospacedFont.family
                    label2.wrapMode: Text.Wrap
                }

                Repeater {
                    model: agent.details

                    delegate: Maui.FlexSectionItem {
                        Layout.fillWidth: true
                        flat: true
                        visible: root.showDetails && modelData.key !== "Action"
                        label1.text: modelData.key
                        label2.text: modelData.value
                        label2.wrapMode: Text.Wrap
                    }
                }

                Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    flat: true
                    visible: root.showDetails && agent.vendorUrl.length > 0
                    label1.text: qsTr("Vendor URL")
                    label2.text: agent.vendorUrl
                    label2.wrapMode: Text.Wrap
                }
            }
        }
    }

    Shortcut {
        sequence: Qt.Key_Escape
        onActivated: agent.cancel()
    }

    Connections {
        target: agent

        function onActiveChanged() {
            if (agent.active) {
                root.resetTimeout()
                if (passwordField.visible)
                    passwordField.forceActiveFocus()
            } else {
                inactivityTimer.stop()
                root.remainingSeconds = root.timeoutSeconds
            }
        }

        function onRequestChanged() {
            root.resetTimeout()
        }

        function onPromptChanged() {
            if (agent.prompt.length > 0) {
                passwordField.clear()
                passwordField.forceActiveFocus()
            }
        }
    }
}

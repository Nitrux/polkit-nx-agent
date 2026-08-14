import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ApplicationWindow {
    id: root
    title: qsTr("Authentication Required")
    width: 520
    height: 460
    minimumWidth: 460
    maximumWidth: 640
    minimumHeight: 380
    maximumHeight: 620
    visible: agent.active
    color: Maui.Theme.backgroundColor
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint

    onClosing: function(close) {
        if (agent.active) {
            close.accepted = false
            agent.cancel()
        }
    }

    Maui.WindowBlur {
        view: root
        geometry: Qt.rect(0, 0, root.width, root.height)
        windowRadius: Maui.Style.radiusV
        enabled: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Maui.Style.space.large
        spacing: Maui.Style.space.medium

        Label {
            Layout.fillWidth: true
            text: qsTr("Authentication Required")
            font: Maui.Style.h2Font
            color: Maui.Theme.textColor
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            Layout.fillWidth: true
            text: agent.message || qsTr("An action requires additional privileges.")
            color: Maui.Theme.textColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            Layout.fillWidth: true
            visible: agent.command.length > 0
            text: agent.command.length > 0 ? qsTr("Command: %1").arg(agent.command) : ""
            color: Maui.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        ComboBox {
            Layout.fillWidth: true
            visible: agent.identities.length > 1
            model: agent.identities
            textRole: "label"
            currentIndex: agent.selectedIdentity
            onActivated: agent.selectIdentity(currentIndex)
        }
        Label {
            Layout.fillWidth: true
            visible: agent.identities.length === 1
            text: agent.identities.length === 1
                ? qsTr("Authentication for %1").arg(agent.identities[0].label) : ""
            color: Maui.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
        }

        Maui.SectionHeader {
            Layout.fillWidth: true
            visible: agent.details.length > 0 || agent.vendor.length > 0 || agent.vendorUrl.length > 0
            text1: qsTr("Action details")
            text2: agent.vendor.length > 0 ? agent.vendor : agent.vendorUrl
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: agent.details.length > 0 || agent.vendor.length > 0 || agent.vendorUrl.length > 0
            spacing: Maui.Style.space.small
            Repeater {
                model: agent.details
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.preferredWidth: 130
                        text: modelData.key
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData.value
                        color: Maui.Theme.textColor
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                visible: agent.vendorUrl.length > 0
                text: agent.vendorUrl
                color: Maui.Theme.linkColor
                elide: Text.ElideRight
            }
        }

        Label {
            Layout.fillWidth: true
            visible: agent.info.length > 0
            text: agent.info
            color: Maui.Theme.linkColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            Layout.fillWidth: true
            visible: agent.error.length > 0
            text: agent.error
            color: Maui.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        Maui.TextField {
            id: passwordField
            Layout.fillWidth: true
            visible: agent.prompt.length > 0
            placeholderText: agent.prompt || qsTr("Password")
            echoMode: agent.echo ? TextInput.Normal : TextInput.Password
            onAccepted: {
                if (text.length > 0) {
                    agent.submitResponse(text)
                    text = ""
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Button { text: qsTr("Cancel"); onClicked: agent.cancel() }
            Button {
                text: qsTr("Authenticate")
                visible: passwordField.visible
                enabled: passwordField.text.length > 0
                onClicked: {
                    agent.submitResponse(passwordField.text)
                    passwordField.text = ""
                }
            }
        }
    }

    Connections {
        target: agent
        function onActiveChanged() {
            if (agent.active && passwordField.visible) passwordField.forceActiveFocus()
        }
        function onPromptChanged() {
            if (agent.prompt.length > 0) {
                passwordField.text = ""
                passwordField.forceActiveFocus()
            }
        }
    }
}

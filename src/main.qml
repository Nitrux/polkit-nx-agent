import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ApplicationWindow {
    id: root

    title: qsTr("Nitrux PolicyKit Agent")
    width: 440
    height: 600
    minimumWidth: 440
    maximumWidth: 440
    minimumHeight: 360
    maximumHeight: 600
    visible: agent.active
    color: Qt.transparent
    background: null
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint

    property var selectedIdentity: agent.selectedIdentity >= 0 && agent.selectedIdentity < agent.identities.length
        ? agent.identities[agent.selectedIdentity] : null
    property string displayedCommand: agent.command.length > 0 ? agent.command : commandFromMessage(agent.message)

    function commandFromMessage(message) {
        const match = message.match(/[\u0060'"\u201c\u201d\u2018\u2019]([^\u0060'"\u201c\u201d\u2018\u2019]+)[\u0060'"\u201c\u201d\u2018\u2019]/)
        return match ? match[1] : ""
    }

    function submitResponse() {
        if (passwordField.text.length > 0) {
            agent.submitResponse(passwordField.text)
            passwordField.clear()
        }
    }

    onClosing: function(close) {
        if (agent.active) {
            close.accepted = false
            agent.cancel()
        }
    }

    Maui.SettingsDialog {
        id: authenticationDialog

        width: root.width
        height: root.height
        maxWidth: 640
        maxHeight: 520
        closeButtonVisible: false
        autoClose: false
        closePolicy: Popup.NoAutoClose
        Maui.Controls.title: ""
        headBar.visible: false
        actionBar.Layout.alignment: Qt.AlignHCenter
        actionBar.Layout.fillWidth: false
        actionBar.Layout.preferredWidth: root.width / 2
        actionBar.Layout.maximumWidth: root.width / 2

        actions: [
            Action {
                text: qsTr("Cancel")
                onTriggered: agent.cancel()
            },
            Action {
                text: qsTr("Authorize")
                enabled: passwordField.text.length > 0
                onTriggered: root.submitResponse()
            }
        ]

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Authorization Required")
                text2: root.displayedCommand.length > 0
                    ? qsTr("Authentication is needed to run the following program as the super user:")
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

            Maui.Chip {
                Layout.alignment: Qt.AlignHCenter
                visible: root.displayedCommand.length > 0
                text: root.displayedCommand
                font.family: Maui.Style.monospacedFont.family
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumHeight: Maui.Style.space.small
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
                Layout.topMargin: Maui.Style.space.medium
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
                onActivated: agent.selectIdentity(currentIndex)
            }

            Maui.TextField {
                id: passwordField
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Maui.Style.space.medium
                Layout.preferredWidth: parent.width / 2
                Layout.maximumWidth: parent.width / 2
                visible: agent.prompt.length > 0
                placeholderText: agent.prompt || qsTr("Password")
                echoMode: agent.echo ? TextInput.Normal : TextInput.Password
                Maui.Controls.status: agent.error.length > 0 ? Maui.Controls.Negative : Maui.Controls.Normal
                onAccepted: root.submitResponse()
            }

            Label {
                Layout.fillWidth: true
                visible: agent.info.length > 0 || agent.error.length > 0
                text: agent.error.length > 0 ? agent.error : agent.info
                color: agent.error.length > 0 ? Maui.Theme.negativeTextColor : Maui.Theme.linkColor
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Maui.FlexSectionItem {
                Layout.fillWidth: true
                label1.text: qsTr("Details")
                label2.text: qsTr("PolicyKit action and vendor information")
                flat: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Maui.Style.space.small

                Maui.FlexSectionItem {
                    label1.text: qsTr("Identity")
                    label2.text: root.selectedIdentity ? root.selectedIdentity.label : ""
                }

                Maui.FlexSectionItem {
                    label1.text: qsTr("Action ID")
                    label2.text: agent.actionId
                    label2.font.family: Maui.Style.monospacedFont.family
                }

                Maui.FlexSectionItem {
                    visible: root.displayedCommand.length > 0
                    label1.text: qsTr("Program")
                    label2.text: root.displayedCommand
                    label2.font.family: Maui.Style.monospacedFont.family
                }

                Repeater {
                    model: agent.details

                    delegate: Maui.FlexSectionItem {
                        visible: modelData.key !== "Action"
                        label1.text: modelData.key
                        label2.text: modelData.value
                        label2.elide: Text.ElideMiddle
                    }
                }

                Maui.FlexSectionItem {
                    visible: agent.vendorUrl.length > 0
                    label1.text: qsTr("Vendor URL")
                    label2.text: agent.vendorUrl
                    label2.elide: Text.ElideMiddle
                }
            }
        }

        onCloseTriggered: agent.cancel()

        Keys.onEscapePressed: function(event) {
            agent.cancel()
            event.accepted = true
        }

        Component.onCompleted: open()
    }

    Connections {
        target: agent

        function onActiveChanged() {
            if (agent.active) {
                if (!authenticationDialog.opened)
                    authenticationDialog.open()
                if (passwordField.visible)
                    passwordField.forceActiveFocus()
            } else if (authenticationDialog.opened) {
                authenticationDialog.close()
            }
        }

        function onPromptChanged() {
            if (agent.prompt.length > 0) {
                passwordField.clear()
                passwordField.forceActiveFocus()
            }
        }
    }
}

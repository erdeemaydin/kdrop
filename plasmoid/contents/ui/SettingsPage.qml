// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page
    required property var app
    readonly property var st: app.st
    spacing: Kirigami.Units.smallSpacing

    component Section: Kirigami.Heading {
        level: 4
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
    }
    component Hint: PC3.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }

    // ---------------------------------------------------------------- receiving
    Section { text: "Receiving"; Layout.topMargin: 0 }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing

        PC3.Label { text: "Save to:" }
        RowLayout {
            Layout.fillWidth: true
            PC3.TextField {
                Layout.fillWidth: true
                readOnly: true
                text: page.st.dir || ""
            }
            PC3.ToolButton {
                icon.name: "document-open-folder"
                onClicked: page.app.chooseFolder()
                PC3.ToolTip.text: "Choose folder"; PC3.ToolTip.visible: hovered
            }
        }

        PC3.Label { text: "Visible as:" }
        PC3.TextField {
            Layout.fillWidth: true
            placeholderText: page.st.hostname || ""
            text: page.st.name || ""
            onEditingFinished: if (text !== (page.st.name || "")) page.app.run(["set", "name", text])
        }

        PC3.Label { text: "Stay visible:" }
        RowLayout {
            DurationBox { app: page.app }
            PC3.Label { text: "after the last transfer" }
        }
    }

    // ---------------------------------------------------------------- trusted
    Section { text: "Trusted devices" }
    PC3.CheckBox {
        Layout.fillWidth: true
        text: "Accept from trusted devices without asking"
        checked: page.st.auto_accept_trusted !== false
        onToggled: page.app.run(["set", "auto_accept_trusted", checked ? "true" : "false"])
    }
    Hint {
        text: (page.st.trusted || []).length
              ? "Files from these devices are saved without a prompt. Everyone else gets Accept / Decline."
              : "No trusted devices. Every incoming transfer asks first."
    }
    Repeater {
        model: page.st.trusted || []
        delegate: RowLayout {
            required property string modelData
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "security-high"
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
            }
            PC3.Label { text: modelData; Layout.fillWidth: true; elide: Text.ElideRight }
            PC3.ToolButton {
                icon.name: "list-remove"
                text: "Remove"
                onClicked: page.app.run(["untrust", modelData])
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        readonly property var candidates: (page.st.devices || []).filter(d => !page.app.isTrusted(d))
        visible: candidates.length > 0
        PC3.ComboBox {
            id: addTrusted
            Layout.fillWidth: true
            model: parent.candidates
        }
        PC3.Button {
            icon.name: "list-add"
            text: "Trust"
            enabled: addTrusted.currentIndex >= 0
            onClicked: page.app.run(["trust", addTrusted.currentText])
        }
    }

    // ---------------------------------------------------------------- devices
    Section { text: "Saved devices" }
    Hint {
        visible: (page.st.devices || []).length === 0
        text: "None yet. Use Search on the main page."
    }
    Repeater {
        model: page.st.devices || []
        delegate: RowLayout {
            required property string modelData
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "computer-tablet"
                implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
            }
            PC3.Label { text: modelData; Layout.fillWidth: true; elide: Text.ElideRight }
            PC3.ToolButton {
                icon.name: "edit-delete-remove"
                text: "Forget"
                onClicked: page.app.run(["forget", modelData])
            }
        }
    }

    // ---------------------------------------------------------------- wi-fi
    Section { text: "Wi-Fi" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing

        PC3.Label { text: "Keep AirDrop on:" }
        RowLayout {
            PC3.SpinBox {
                from: 0; to: 300; stepSize: 10
                value: page.st.keep_on_seconds || 0
                onValueModified: page.app.run(["set", "keep_on_seconds", String(value)])
            }
            PC3.Label { text: "s after a send" }
        }

        PC3.Label { text: "Search for up to:" }
        RowLayout {
            PC3.SpinBox {
                from: 3; to: 30
                value: page.st.browse_seconds || 10
                onValueModified: page.app.run(["set", "browse_seconds", String(value)])
            }
            PC3.Label { text: "s" }
        }
    }
    Hint {
        text: "Most Wi-Fi cards can't do AirDrop and stay online at the same time, so Wi-Fi pauses "
              + "while AirDrop is on. Each reconnect takes a few seconds (longer on eduroam). "
              + "Keeping AirDrop on for a while after a send lets several sends share one reconnect. "
              + "A search ends early as soon as devices answer."
    }

    Hint {
        Layout.topMargin: Kirigami.Units.largeSpacing
        text: "KDrop " + (page.st.version || "") + " · uses owly for AirDrop · not affiliated with Apple or KDE"
    }
}

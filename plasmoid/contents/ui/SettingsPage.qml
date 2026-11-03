// SPDX-License-Identifier: MIT
// Shown in its own window (KDrop Settings).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page
    required property var app
    readonly property var st: app.st
    spacing: Kirigami.Units.smallSpacing

    // Unsaved changes. The window's Save button writes them all at once. The page is rebuilt each
    // time the window opens, so closing without saving simply drops them.
    property var draft: ({})
    readonly property bool dirty: Object.keys(draft).length > 0
    function val(key, fallback) {
        return draft[key] !== undefined ? draft[key] : (st[key] !== undefined ? st[key] : fallback)
    }
    function change(key, value) {
        const d = Object.assign({}, draft)
        if (value === st[key]) delete d[key]; else d[key] = value
        draft = d
    }
    function save() {
        if (!dirty) return
        const args = ["set"]
        for (const k in draft) args.push(k, String(draft[k]))
        app.run(args)
        draft = {}
    }

    component Section: Kirigami.Heading {
        level: 4
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing * 2
    }
    component Hint: QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }

    // ---------------------------------------------------------------- widget or app
    Section { text: "Run KDrop as"; Layout.topMargin: 0; visible: page.st.plasma !== false }
    QQC2.ButtonGroup { id: modeGroup }
    QQC2.RadioButton {
        visible: page.st.plasma !== false
        QQC2.ButtonGroup.group: modeGroup
        text: "Panel widget"
        checked: page.val("mode", "widget") === "widget"
        onClicked: page.change("mode", "widget")
    }
    QQC2.RadioButton {
        visible: page.st.plasma !== false
        QQC2.ButtonGroup.group: modeGroup
        text: "Separate app (in the app menu, with a tray icon while open)"
        checked: page.val("mode", "widget") === "app"
        onClicked: page.change("mode", "app")
    }
    Hint {
        visible: page.st.plasma !== false
        text: "When you save, KDrop moves for you: the panel widget is removed and KDrop opens as an "
              + "app, or the other way round."
    }

    // ---------------------------------------------------------------- receiving
    Section { text: "Receiving" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing

        QQC2.Label { text: "Save to:" }
        RowLayout {
            Layout.fillWidth: true
            QQC2.TextField {
                Layout.fillWidth: true
                readOnly: true
                text: page.val("dir", "")
            }
            QQC2.Button {
                icon.name: "document-open-folder"
                onClicked: page.app.chooseFolder()
                QQC2.ToolTip.text: "Choose folder"; QQC2.ToolTip.visible: hovered
            }
        }

        QQC2.Label { text: "Visible as:" }
        QQC2.TextField {
            Layout.fillWidth: true
            placeholderText: page.st.hostname || ""
            text: page.val("name", "")
            onTextEdited: page.change("name", text)
        }

        QQC2.Label { text: "Stay visible:" }
        RowLayout {
            DurationBox {
                app: page.app
                seconds: page.val("receive_seconds", 180)
                onPicked: s => page.change("receive_seconds", s)
            }
            QQC2.Label { text: "after the last transfer" }
        }
    }

    // ---------------------------------------------------------------- trusted
    Section { text: "Trusted devices" }
    Hint { text: "Trust, Remove and Forget take effect right away." }
    QQC2.CheckBox {
        Layout.fillWidth: true
        text: "Accept from trusted devices without asking"
        checked: page.val("auto_accept_trusted", true) !== false
        onToggled: page.change("auto_accept_trusted", checked)
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
            QQC2.Label { text: modelData; Layout.fillWidth: true; elide: Text.ElideRight }
            QQC2.Button {
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
        QQC2.ComboBox {
            id: addTrusted
            Layout.fillWidth: true
            model: parent.candidates
        }
        QQC2.Button {
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
        text: "None yet. Use Search in KDrop."
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
            QQC2.Label { text: modelData; Layout.fillWidth: true; elide: Text.ElideRight }
            QQC2.Button {
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

        QQC2.Label { text: "Keep AirDrop on:" }
        RowLayout {
            QQC2.SpinBox {
                from: 0; to: 300; stepSize: 10
                value: page.val("keep_on_seconds", 0)
                onValueModified: page.change("keep_on_seconds", value)
            }
            QQC2.Label { text: "s after a send" }
        }

        QQC2.Label { text: "Search for up to:" }
        RowLayout {
            QQC2.SpinBox {
                from: 3; to: 30
                value: page.val("browse_seconds", 10)
                onValueModified: page.change("browse_seconds", value)
            }
            QQC2.Label { text: "s" }
        }
    }
    Hint {
        text: "Most Wi-Fi cards can't do AirDrop and stay online at the same time, so Wi-Fi pauses "
              + "while AirDrop is on. Each reconnect takes a few seconds (longer on eduroam). "
              + "Keeping AirDrop on for a while after a send lets several sends share one reconnect. "
              + "A search ends early as soon as devices answer."
    }

    Hint {
        Layout.topMargin: Kirigami.Units.largeSpacing * 2
        Layout.bottomMargin: Kirigami.Units.gridUnit
        text: "KDrop " + (page.st.version || "") + " · uses owly for AirDrop · not affiliated with Apple or KDE"
    }
}

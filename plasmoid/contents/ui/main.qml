// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import QtQuick.Controls as QQC2

PlasmoidItem {
    id: root

    readonly property string helper: "\"$HOME/.local/bin/kdrop\""
    property var st: ({ radio: false, wifi: "connected", jobs: {}, devices: [], trusted: [],
                        receive_seconds: 180, dir: "", host: "", owly: true })
    // files waiting for you to click a device; nothing is sent before that click
    property var pending: []
    property bool pinned: true
    property bool pickingFiles: false
    property bool pickingFolder: false
    onExpandedChanged: {
        if (expanded) {
            pinned = true
        } else if (pickingFiles) {
            exec.connectSource(helper + " _cancel-pick #" + Date.now())
        }
    }
    readonly property url logo: Qt.resolvedUrl("../icons/kdrop.svg")
    // Anywhere but a panel (an app window via plasmawindowed, or the desktop) the header leaves
    // out logo and name: a window's title bar shows them already. (plasmawindowed reports its
    // form factor as Application or Planar depending on saved state, so test for a panel.)
    readonly property bool windowed: Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
                                     && Plasmoid.formFactor !== PlasmaCore.Types.Vertical

    readonly property var sendJob: st.jobs.send || null
    readonly property var recvJob: st.jobs.receive || null
    readonly property var browseJob: st.jobs.browse || null
    readonly property bool sending: !!(sendJob && sendJob.active)
    readonly property bool receiving: !!(recvJob && recvJob.active)
    readonly property bool browsing: !!(browseJob && browseJob.active)
    readonly property bool busy: sending || receiving || browsing || st.radio

    Plasmoid.icon: "io.github.erdeemaydin.kdrop"
    Plasmoid.status: busy || pending.length ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    // keep open by default (or while dialogs take focus) so files can be dragged from desktop/Dolphin
    hideOnWindowDeactivate: !pinned && !pickingFiles && !pickingFolder
                            && !fileDialog.visible && !folderDialog.visible && !settingsWindow.visible
    expandedOnDragHover: true
    toolTipMainText: "KDrop"
    toolTipSubText: {
        const j = sendJob || recvJob || browseJob
        if (j && j.text && (j.active || j.state === "error")) return j.text
        return "Drop files here, then choose a device"
    }
    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 14

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "KDrop Settings…"
            icon.name: "configure"
            onTriggered: root.openSettings()
        },
        PlasmaCore.Action {
            text: "Stop AirDrop && Reconnect Wi-Fi"
            icon.name: "network-wireless"
            enabled: root.busy
            onTriggered: root.run(["stop"])
        },
        PlasmaCore.Action {
            text: "Restart KDrop"
            icon.name: "view-refresh"
            onTriggered: { root.pending = []; root.run(["restart"]) }
        }
    ]

    // ------------------------------------------------------------ backend
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function run(args) {
        exec.connectSource(helper + " " + args.map(q).join(" ") + " #" + Date.now())
        refreshSoon.restart()
    }
    function poll() { exec.connectSource(helper + " status #" + Date.now()) }
    function fmtDuration(sec) {
        const m = Math.floor(sec / 60), s = sec % 60
        return !m ? s + " s" : !s ? m + " min" : m + " min " + s + " s"
    }
    function isTrusted(name) { return (st.trusted || []).indexOf(name) >= 0 }

    function addFiles(urls) {
        const list = []
        for (let i = 0; i < urls.length; ++i) list.push(urls[i].toString())
        if (!list.length) return
        pending = list
        expanded = true
    }
    function sendTo(device) {
        if (!device || !pending.length) return
        run(["send", "--to", device].concat(pending))
        pending = []
    }
    function fileName(u) {
        const s = decodeURIComponent(String(u)).replace(/\/$/, "")
        return s.substring(s.lastIndexOf("/") + 1)
    }
    function urlToPath(u) { return decodeURIComponent(String(u).replace(/^file:\/\//, "")) }
    function dialogGeom() {
        const aw = Screen.desktopAvailableWidth || 1280
        const ah = Screen.desktopAvailableHeight || 800
        const w = Math.min(Math.max(480, Math.round(aw * 0.65)), 920, Math.max(320, aw - 64))
        const h = Math.min(Math.max(360, Math.round(ah * 0.68)), 600, Math.max(240, ah - 64))
        return w + "x" + h
    }
    function handlePick(source, data, onOk, fallback) {
        if (data["exit code"] !== 0) {
            console.warn("kdrop:", source, data.stderr)
            fallback()
            return false
        }
        try {
            onOk(data.stdout ? JSON.parse(data.stdout) : null)
            return true
        } catch (e) {
            console.warn("kdrop:", source, e)
            return false
        }
    }
    function pickFiles() {
        if (root.sending || root.pickingFiles) return
        root.pickingFiles = true
        exec.connectSource(helper + " _pick files " + q(dialogGeom()) + " #" + Date.now())
    }
    function chooseFolder() {
        if (root.pickingFolder) return
        root.pickingFolder = true
        exec.connectSource(helper + " _pick folder " + q(dialogGeom()) + " " + q(root.st.dir || "") + " #" + Date.now())
    }
    function openSettings() {
        settingsWindow.show()
        settingsWindow.raise()
        settingsWindow.requestActivate()
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source.indexOf("kdrop\" _pick files ") >= 0) {
                root.pickingFiles = false
                handlePick(source, data, res => {
                    if (res && res.urls && res.urls.length) root.addFiles(res.urls)
                }, () => { if (root.expanded) fileDialog.open() })
            } else if (source.indexOf("kdrop\" _pick folder ") >= 0) {
                root.pickingFolder = false
                handlePick(source, data, res => {
                    if (res && res.path && settingsLoader.item) {
                        settingsLoader.item.change("dir", res.path)
                    }
                }, () => folderDialog.open())
            } else {
                if (data["exit code"] !== 0) console.warn("kdrop:", source, data.stderr)
                if (source.indexOf("kdrop\" status") >= 0 && data.stdout) {
                    try { root.st = JSON.parse(data.stdout) } catch (e) {}
                }
            }
            disconnectSource(source)
        }
    }
    Timer {
        interval: (root.busy || root.expanded || root.st.wifi === "connecting") ? 1000 : 5000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.poll()
    }
    Timer { id: refreshSoon; interval: 300; onTriggered: root.poll() }
    Component.onCompleted: refreshSoon.start()

    FileDialog {
        id: fileDialog
        title: "Choose files to send"
        fileMode: FileDialog.OpenFiles
        onAccepted: root.addFiles(selectedFiles)
        onRejected: root.expanded = true
    }
    FolderDialog {
        id: folderDialog
        title: "Save received files to"
        currentFolder: "file://" + root.st.dir
        onAccepted: if (settingsLoader.item) settingsLoader.item.change("dir", root.urlToPath(selectedFolder))
    }

    // ------------------------------------------------------------ settings window
    Window {
        id: settingsWindow
        title: "KDrop Settings"
        width: Kirigami.Units.gridUnit * 28
        height: Math.min(Kirigami.Units.gridUnit * 44, Screen.desktopAvailableHeight * 0.85)
        minimumWidth: Kirigami.Units.gridUnit * 22
        minimumHeight: Kirigami.Units.gridUnit * 16
        flags: Qt.Dialog
        color: Kirigami.Theme.backgroundColor
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        readonly property var page: settingsLoader.item

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            QQC2.ScrollView {
                id: settingsScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                contentHeight: settingsLoader.height + Kirigami.Units.gridUnit
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
                // rebuilt on every open: starts from the saved settings, unsaved edits vanish on close
                Loader {
                    id: settingsLoader
                    active: settingsWindow.visible
                    x: Kirigami.Units.gridUnit
                    y: Kirigami.Units.gridUnit
                    width: settingsScroll.availableWidth - Kirigami.Units.gridUnit * 2
                    height: item ? item.implicitHeight + Kirigami.Units.gridUnit : 0
                    sourceComponent: SettingsPage { app: root }
                }
            }
            Kirigami.Separator { Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                QQC2.Label {
                    Layout.fillWidth: true
                    opacity: 0.7
                    text: settingsWindow.page && settingsWindow.page.dirty ? "Unsaved changes" : ""
                }
                QQC2.Button {
                    readonly property bool dirty: !!settingsWindow.page && settingsWindow.page.dirty
                    text: dirty ? "Cancel" : "Close"
                    icon.name: dirty ? "dialog-cancel" : "window-close"
                    onClicked: settingsWindow.close()
                }
                QQC2.Button {
                    text: "Save"
                    icon.name: "document-save"
                    highlighted: true
                    enabled: !!settingsWindow.page && settingsWindow.page.dirty
                    onClicked: { settingsWindow.page.save(); settingsWindow.close() }
                }
            }
        }
    }

    // ------------------------------------------------------------ panel icon
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: root.logo
            active: compact.containsMouse || compactDrop.containsDrag
        }
        PC3.BusyIndicator {
            visible: root.busy
            running: visible
            anchors.right: parent.right; anchors.bottom: parent.bottom
            width: parent.width / 2; height: width
        }
        DropArea {
            id: compactDrop
            anchors.fill: parent
            onDropped: drop => { if (drop.hasUrls) root.addFiles(drop.urls) }
        }
    }

    // ------------------------------------------------------------ popup
    fullRepresentation: PlasmaExtras.Representation {
        // Always tall enough for everything on the page: status lines appear during a search or
        // send, and the popup grows with them. It's the minimum too, because Plasma reopens a
        // popup at the size it last had, which would cut the bottom off once the page grew.
        readonly property real fitHeight: heading.implicitHeight + mainPage.implicitHeight
                                          + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: fitHeight
        Layout.minimumHeight: fitHeight

        header: PlasmaExtras.PlasmoidHeading {
            id: heading
            RowLayout {
                anchors.fill: parent
                Kirigami.Icon {
                    visible: !root.windowed
                    source: root.logo
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth
                }
                Kirigami.Heading {
                    level: 2
                    Layout.fillWidth: true
                    text: root.windowed ? "" : "KDrop"
                }
                PC3.ToolButton {
                    icon.name: "folder-download"
                    text: "Received"
                    onClicked: Qt.openUrlExternally("file://" + root.st.dir)
                    PC3.ToolTip.text: root.st.dir; PC3.ToolTip.visible: hovered
                }
                PC3.ToolButton {
                    icon.name: "configure"
                    onClicked: root.openSettings()
                    PC3.ToolTip.text: "Settings"; PC3.ToolTip.visible: hovered
                }
                PC3.ToolButton {
                    id: pinButton
                    visible: !root.windowed
                    icon.name: "window-pin"
                    checkable: true
                    checked: root.pinned
                    onToggled: {
                        root.pinned = checked
                        checked = Qt.binding(() => root.pinned)
                    }
                    PC3.ToolTip.text: "Keep open"; PC3.ToolTip.visible: hovered
                }
            }
        }

        ColumnLayout {
            id: mainPage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Kirigami.Units.largeSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !root.st.owly
                type: Kirigami.MessageType.Error
                text: "owly is not installed. KDrop needs it for AirDrop: https://github.com/t4t5/owly"
            }

            // ---- step 1: files
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * (root.pending.length ? 3.5 : 5)
                radius: Kirigami.Units.cornerRadius
                color: zoneDrop.containsDrag || zoneMouse.containsMouse
                       ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
                       : Qt.alpha(Kirigami.Theme.textColor, 0.05)
                border.width: 2
                border.color: zoneDrop.containsDrag ? Kirigami.Theme.highlightColor
                                                    : Qt.alpha(Kirigami.Theme.textColor, 0.2)
                opacity: root.sending ? 0.5 : 1

                MouseArea {
                    id: zoneMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.sending && !root.pickingFiles
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickFiles()
                }
                DropArea {
                    id: zoneDrop
                    anchors.fill: parent
                    enabled: !root.sending
                    onDropped: drop => { if (drop.hasUrls) root.addFiles(drop.urls) }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: root.pending.length ? "document-multiple" : "document-send"
                        implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: root.pending.length
                            ? root.fileName(root.pending[0])
                              + (root.pending.length > 1 ? "  +" + (root.pending.length - 1) + " more" : "")
                              + "\nNow click a device below to send"
                            : "Drop files here or click to choose"
                    }
                    PC3.ToolButton {
                        visible: root.pending.length > 0
                        icon.name: "edit-clear"
                        onClicked: root.pending = []
                        PC3.ToolTip.text: "Clear selection"; PC3.ToolTip.visible: hovered
                    }
                }
            }

            // ---- step 2: device
            RowLayout {
                Layout.fillWidth: true
                PC3.Label {
                    Layout.fillWidth: true
                    text: "Send to:"
                    opacity: root.pending.length ? 1 : 0.6
                }
                PC3.ToolButton {
                    icon.name: "view-refresh"
                    text: root.browsing ? "Searching…" : "Search"
                    enabled: !root.browsing && !root.sending
                    onClicked: root.run(["browse"])
                    PC3.ToolTip.text: "Find nearby devices (pauses Wi-Fi for a few seconds)"
                    PC3.ToolTip.visible: hovered
                }
            }
            PC3.Label {
                Layout.fillWidth: true
                visible: (root.st.devices || []).length === 0
                wrapMode: Text.Wrap
                opacity: 0.7
                text: "No devices yet. On the iPhone/iPad set AirDrop to Everyone, then press Search."
            }
            Repeater {
                model: root.st.devices || []
                delegate: PC3.Button {
                    required property string modelData
                    Layout.fillWidth: true
                    icon.name: "computer-tablet"
                    text: modelData + (root.isTrusted(modelData) ? "  ✓" : "")
                    enabled: root.pending.length > 0 && !root.sending
                    onClicked: root.sendTo(modelData)
                    PC3.ToolTip.text: root.pending.length ? "Send the selected files to " + modelData
                                                           : "Choose files first"
                    PC3.ToolTip.visible: hovered
                }
            }

            // ---- status
            Repeater {
                model: ["send", "browse", "receive"]
                delegate: ColumnLayout {
                    required property string modelData
                    readonly property var job: root.st.jobs[modelData] || null
                    visible: !!job && !!job.text
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
                            source: !job ? "" : job.state === "error" ? "dialog-error"
                                  : job.state === "done" ? "emblem-success"
                                  : modelData === "receive" ? "folder-download" : "document-send"
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: job ? job.text + (job.files && modelData === "send" ? "\n" + job.files : "") : ""
                        }
                    }
                    PC3.ProgressBar {
                        Layout.fillWidth: true
                        visible: !!job && job.active && modelData === "send"
                        from: 0; to: 100
                        indeterminate: !!job && job.state !== "sending"
                        value: job && job.progress !== undefined ? job.progress : 0
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.st.wifi === "airdrop" || root.st.wifi === "connecting"
                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
                    source: root.st.wifi === "airdrop" ? "network-wireless-hotspot" : "network-wireless-acquiring"
                }
                PC3.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: root.st.wifi === "connecting" ? "Reconnecting Wi-Fi…"
                        : root.st.keep_on && !root.sending && !root.receiving && !root.browsing
                          ? "Wi-Fi paused · AirDrop stays on briefly for another send"
                          : "Wi-Fi paused while AirDrop is on"
                }
                PC3.ToolButton {
                    visible: root.st.radio
                    icon.name: "network-wireless"
                    text: "Reconnect now"
                    onClicked: root.run(["stop"])
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // ---- receive
            RowLayout {
                Layout.fillWidth: true
                PC3.Button {
                    Layout.fillWidth: true
                    icon.name: root.receiving ? "process-stop" : "folder-download"
                    text: root.receiving ? "Stop receiving" : "Receive"
                    onClicked: root.receiving ? root.run(["stop"]) : root.run(["receive"])
                }
                DurationBox {
                    app: root
                    seconds: root.st.receive_seconds || 180
                    onPicked: s => root.run(["set", "receive_seconds", String(s)])
                    visible: !root.receiving
                    PC3.ToolTip.text: "How long to stay visible after the last transfer"
                    PC3.ToolTip.visible: hovered
                }
            }
            PC3.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: (root.st.host ? "Visible as “" + root.st.host + "” while receiving. " : "")
                      + "Senders need AirDrop set to Everyone."
            }
        }
    }
}

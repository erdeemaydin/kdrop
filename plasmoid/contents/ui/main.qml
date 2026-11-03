// SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string helper: "\"$HOME/.local/bin/kdrop\""
    property var st: ({ radio: false, wifi: "connected", jobs: {}, devices: [], trusted: [],
                        receive_minutes: 3, dir: "", host: "", owly: true })
    // files waiting for you to click a device; nothing is sent before that click
    property var pending: []
    property bool showSettings: false

    readonly property var sendJob: st.jobs.send || null
    readonly property var recvJob: st.jobs.receive || null
    readonly property var browseJob: st.jobs.browse || null
    readonly property bool sending: !!(sendJob && sendJob.active)
    readonly property bool receiving: !!(recvJob && recvJob.active)
    readonly property bool browsing: !!(browseJob && browseJob.active)
    readonly property bool busy: sending || receiving || browsing || st.radio

    Plasmoid.icon: busy ? "network-wireless-hotspot" : "document-send"
    Plasmoid.status: busy || pending.length ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    // the file and folder dialogs take focus; don't let that close the popup
    hideOnWindowDeactivate: !fileDialog.visible && !folderDialog.visible
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
            onTriggered: { root.showSettings = true; root.expanded = true }
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
            onTriggered: { root.pending = []; root.showSettings = false; root.run(["restart"]) }
        }
    ]

    // ------------------------------------------------------------ backend
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }
    function run(args) {
        exec.connectSource(helper + " " + args.map(q).join(" ") + " #" + Date.now())
        refreshSoon.restart()
    }
    function poll() { exec.connectSource(helper + " status #" + Date.now()) }
    function isTrusted(name) { return (st.trusted || []).indexOf(name) >= 0 }

    function addFiles(urls) {
        const list = []
        for (let i = 0; i < urls.length; ++i) list.push(urls[i].toString())
        if (!list.length) return
        pending = list
        showSettings = false
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
    function chooseFolder() { folderDialog.open() }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (data["exit code"] !== 0) console.warn("kdrop:", source, data.stderr)
            if (source.indexOf("kdrop\" status") >= 0 && data.stdout) {
                try { root.st = JSON.parse(data.stdout) } catch (e) {}
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
        onAccepted: { root.run(["set", "dir", root.urlToPath(selectedFolder)]); root.expanded = true }
        onRejected: root.expanded = true
    }

    // ------------------------------------------------------------ panel icon
    compactRepresentation: MouseArea {
        id: compact
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
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
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: (root.showSettings
                                 ? Math.min(settings.implicitHeight, Kirigami.Units.gridUnit * 26)
                                 : mainPage.implicitHeight) + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                PC3.ToolButton {
                    visible: root.showSettings
                    icon.name: "go-previous"
                    onClicked: root.showSettings = false
                    PC3.ToolTip.text: "Back"; PC3.ToolTip.visible: hovered
                }
                Kirigami.Heading {
                    level: 2
                    Layout.fillWidth: true
                    text: root.showSettings ? "Settings" : "KDrop"
                }
                PC3.ToolButton {
                    visible: !root.showSettings
                    icon.name: "folder-download"
                    text: "Received"
                    onClicked: Qt.openUrlExternally("file://" + root.st.dir)
                    PC3.ToolTip.text: root.st.dir; PC3.ToolTip.visible: hovered
                }
                PC3.ToolButton {
                    visible: !root.showSettings
                    icon.name: "configure"
                    onClicked: root.showSettings = true
                    PC3.ToolTip.text: "Settings"; PC3.ToolTip.visible: hovered
                }
            }
        }

        PC3.ScrollView {
            id: settingsScroll
            visible: root.showSettings
            anchors.fill: parent
            contentWidth: availableWidth
            PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff
            SettingsPage {
                id: settings
                app: root
                width: settingsScroll.availableWidth
            }
        }

        ColumnLayout {
            id: mainPage
            visible: !root.showSettings
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
                    enabled: !root.sending
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fileDialog.open()
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
            PC3.Button {
                Layout.fillWidth: true
                icon.name: root.receiving ? "process-stop" : "folder-download"
                text: root.receiving ? "Stop receiving"
                                     : "Receive for " + root.st.receive_minutes + " min"
                onClicked: root.receiving ? root.run(["stop"]) : root.run(["receive"])
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

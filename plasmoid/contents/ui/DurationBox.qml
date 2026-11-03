// SPDX-License-Identifier: MIT
// How long to stay visible for receiving.
import QtQuick
import QtQuick.Controls as QQC2

QQC2.ComboBox {
    id: box
    required property var app
    property int seconds: 180
    signal picked(int seconds)

    readonly property var presets: [30, 60, 120, 180, 300, 600, 1800]
    // keep a value set elsewhere (e.g. `kdrop set receive_seconds 45s`) selectable
    readonly property var choices: presets.indexOf(seconds) >= 0 ? presets
                                   : presets.concat([seconds]).sort((a, b) => a - b)

    model: choices.map(s => app.fmtDuration(s))
    currentIndex: choices.indexOf(seconds)
    onActivated: index => picked(choices[index])
}

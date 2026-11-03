// SPDX-License-Identifier: MIT
// How long to stay visible for receiving. Saves the choice as the new default.
import QtQuick
import org.kde.plasma.components as PC3

PC3.ComboBox {
    id: box
    required property var app
    readonly property int seconds: app.st.receive_seconds || 180
    readonly property var presets: [30, 60, 120, 180, 300, 600, 1800]
    // keep a value set elsewhere (e.g. `kdrop set receive_seconds 45s`) selectable
    readonly property var choices: presets.indexOf(seconds) >= 0 ? presets
                                   : presets.concat([seconds]).sort((a, b) => a - b)

    model: choices.map(s => app.fmtDuration(s))
    currentIndex: choices.indexOf(seconds)
    onActivated: index => app.run(["set", "receive_seconds", String(choices[index])])
}

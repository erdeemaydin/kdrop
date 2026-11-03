# KDrop

**AirDrop for KDE Plasma.** A panel widget for sending files to and receiving files from iPhone, iPad and Mac, using real AirDrop, with no app on the Apple device.

<p>
  <img src="docs/main.png" width="420" alt="KDrop popup: two files selected, waiting for a device to be chosen">
  <img src="docs/settings.png" width="420" alt="KDrop settings: receive folder, trusted devices, Wi-Fi options">
</p>

KDrop is a front end for [**owly**](https://github.com/t4t5/owly), which implements Apple's AWDL radio link and the AirDrop protocol on Linux. owly does the hard part. KDrop makes it a two-click job and keeps Wi-Fi interruptions as short as possible.

## Features

- **Send:** drop files on the panel icon (or click to pick them), then click the device to send to. Folders are zipped automatically. Progress and results appear in the popup and as notifications.
- **Explicit receivers only:** KDrop never sends to "whoever answers first". You pick the device every time, and if a different device answers than the one you picked, the send is cancelled before anything is offered.
- **Receive:** one click makes your PC visible for a few minutes. Each incoming transfer asks **Accept / Always accept from this device / Decline**. Received files get *Open* and *Show in folder* actions.
- **Trusted devices:** your own devices can skip the prompt. Manage the list in Settings.
- **Dolphin integration:** right-click any file → *Send via AirDrop* → your device.
- **Short Wi-Fi interruptions:** on most cards AirDrop and Wi-Fi can't run at once, so KDrop turns the AirDrop radio on only for the transfer and gives the card back to NetworkManager immediately. See [Wi-Fi interruptions](#wi-fi-interruptions).
- **Works anywhere:** AirDrop is a direct device-to-device link. It doesn't go through your network, so it works on eduroam, hotel and café Wi-Fi, or with no network at all.

## Requirements

- KDE Plasma 6
- [owly](https://github.com/t4t5/owly) installed (`owly doctor` should say `ready`)
- A Wi-Fi card owly supports. Most recent Intel cards (AX200/AX201/AX210/AX211/BE200) and several MediaTek and Realtek cards work; see [owly's hardware table](https://github.com/t4t5/owly#supported-hardware)
- Python 3, `kdialog`, `notify-send` (standard on Plasma desktops)
- On the Apple device: AirDrop set to **Everyone for 10 minutes** when it should see your PC, or when you send to it

## Install

1. Install owly (Fedora example, see owly's README for other distros):

   ```sh
   sudo dnf install ./owly-*.x86_64.rpm      # from https://github.com/t4t5/owly/releases
   owly doctor                                # should end with "ready"
   ```

   If you use firewalld, let AirDrop in on the AirDrop interface only:

   ```sh
   sudo firewall-cmd --permanent --new-zone=awdl
   sudo firewall-cmd --permanent --zone=awdl --add-interface=awdl0
   sudo firewall-cmd --permanent --zone=awdl --add-port=8771/tcp
   sudo firewall-cmd --permanent --zone=awdl --add-service=mdns
   sudo firewall-cmd --reload
   ```

2. Install KDrop (per user, no root):

   ```sh
   git clone https://github.com/erdeemaydin/kdrop.git
   cd kdrop
   ./install.sh
   ```

3. Right-click the panel → **Add Widgets…** → **KDrop**.

To update, `git pull && ./install.sh`, then `systemctl --user restart plasma-plasmashell`.
To remove, run `./uninstall.sh`.

## Usage

| | |
|---|---|
| **Find your devices** | Set AirDrop on the iPhone/iPad to *Everyone for 10 minutes*, then press **Search**. Found devices are saved. |
| **Send** | Drop files on the icon or popup → click the device. |
| **Receive** | Press **Receive for N min**, then on the Apple device choose your PC in the AirDrop share sheet. |
| **From Dolphin** | Right-click files → *Send via AirDrop* → device. |
| **Command line** | `kdrop send --to "My iPad" photo.jpg`, `kdrop receive`, `kdrop browse`, `kdrop stop`, `kdrop --help` |

## Wi-Fi interruptions

On cards that run owly in *exclusive* mode (every Intel card, for example), Wi-Fi is off while AirDrop is on. KDrop keeps that window short:

- The radio starts when you click a device, Search or Receive, not before, and stops as soon as the job is done.
- A search ends as soon as devices have answered, instead of running its full time.
- **Keep AirDrop on** (Settings) leaves the radio up for N seconds after a send, so several sends in a row share one reconnect. It's off by default.
- The widget shows *Reconnecting Wi-Fi…* until NetworkManager is back.

What's left is NetworkManager reconnecting, which KDrop can't speed up. Measured on eduroam with an AX210: roughly 5 s scanning, 1 s for 802.1X login and 4 s for DHCP. On a home network it's usually a few seconds.

If your access point is on channel 6, 44 or 149 and your card supports owly's *shared* mode, Wi-Fi stays connected the whole time. A second USB Wi-Fi adapter dedicated to AirDrop also avoids interruptions; see owly's README.

## How it works

```
Plasma widget (QML) ─┐
Dolphin service menu ├─▶ kdrop (Python helper) ─▶ owly CLI ─▶ owlyd (system service, AWDL radio)
Command line ────────┘        │
                              └─ runs each job as a systemd user unit, so transfers survive
                                 Plasma restarts; the radio unit has a 30-minute hard limit
                                 so Wi-Fi always comes back
```

Settings live in `~/.config/kdrop.json`.

## Security notes

- KDrop sends only to a device name you clicked, and checks the name of the device that actually answers.
- Incoming transfers always ask unless the sender is on your trusted list. Device names are not authenticated by AirDrop's *Everyone* mode, so only trust names that are unlikely to be imitated, and remember a trusted name is a convenience, not strong security.
- The receive window closes by itself after a few minutes of inactivity.

## Credits and legal

- [owly](https://github.com/t4t5/owly) by t4t5: the AWDL and AirDrop implementation KDrop depends on (MIT).
- AWDL and AirDrop on Linux were first made possible by the research behind [OWL](https://github.com/seemoo-lab/owl) and [OpenDrop](https://github.com/seemoo-lab/opendrop) (Secure Mobile Networking Lab, TU Darmstadt).

KDrop is an independent project. It is not affiliated with, endorsed by or sponsored by Apple Inc. or KDE e.V. AirDrop, iPhone, iPad and Mac are trademarks of Apple Inc. KDE and Plasma are trademarks of KDE e.V.

## License

[MIT](LICENSE)

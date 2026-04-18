# Dash Launch
- The code is 100% AI generated!
- This is a Plasma 6 Gnome-like Applications Dashboard

- open windows on the current desktop
- application search through KRunner services
- a launch grid for installed applications

## Layout

- `package/metadata.json`: plasmoid metadata
- `package/contents/ui/main.qml`: dashboard UI and model wiring

## Install

Install the plasmoid package locally:

```bash
./install.sh
```

Upgrade after edits:

```bash
./install.sh
```

## Preview

If your system has Plasma tooling installed, you can preview it with one of these:

```bash
plasmoidviewer -a /home/mro/plasma-dashboard-launcher/package
```

```bash
plasmawindowed org.kde.plasma.dashlaunch
```

## Notes

- The search view uses the `krunner_services` runner, so it focuses on app launching.
- The open windows panel uses Plasma's task manager model and activates or closes windows directly.
- The UI is pure QML, so the quickest extension path is editing `package/contents/ui/main.qml`.
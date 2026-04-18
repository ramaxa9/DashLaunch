# Dash Launch
- The code is 100% AI generated!
- This is a Plasma 6 Gnome-like Applications Dashboard

### What is implemented
- show opened windows on the current/all screens
- application search through KRunner services
- virtual desktops
- keyboard navigation

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
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import org.kde.iconthemes as KIconThemes
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property string cfg_widgetIcon: ""
    property string cfg_dashboardLayout: "default"
    property string cfg_monitorSelectionMode: "widget"
    property string cfg_targetMonitorName: ""
    property alias cfg_showOnlyCurrentMonitor: showOnlyCurrentMonitor.checked
    property alias cfg_showOnlyCurrentVirtualDesktop: showOnlyCurrentVirtualDesktop.checked
    property alias cfg_cursorBorderColor: cursorBorderColorField.text
    property alias cfg_enableFullscreen: enableFullscreen.checked
    readonly property var availableScreenNames: {
        const screens = Qt.application.screens || [];
        const names = [];

        for (let index = 0; index < screens.length; ++index) {
            const screenName = String(screens[index].name || "").trim();
            names.push(screenName.length > 0 ? screenName : i18n("Monitor %1", index + 1));
        }

        return names;
    }

    function monitorModeIndex() {
        switch (cfg_monitorSelectionMode) {
        case "follow-mouse":
            return 1;
        case "specific":
            return 2;
        default:
            return 0;
        }
    }

    function targetMonitorIndex() {
        return availableScreenNames.indexOf(cfg_targetMonitorName);
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: iconName => page.cfg_widgetIcon = iconName || "view-grid"
    }

    ColorDialog {
        id: colorDialog
        selectedColor: page.cfg_cursorBorderColor || "#7dcfff"

        onAccepted: page.cfg_cursorBorderColor = selectedColor.toString()
    }

    Kirigami.FormLayout {
        ComboBox {
            id: layoutTypeCombo
            Kirigami.FormData.label: i18n("Search layout:")
            Layout.fillWidth: true
            model: [i18n("Default"), i18n("App grid")]

            Component.onCompleted: currentIndex = page.cfg_dashboardLayout === "app-grid" ? 1 : 0

            onActivated: page.cfg_dashboardLayout = currentIndex === 1 ? "app-grid" : "default"
        }

        ComboBox {
            id: monitorModeCombo
            Kirigami.FormData.label: i18n("Open on monitor:")
            Layout.fillWidth: true
            model: [i18n("Widget monitor"), i18n("Follow mouse"), i18n("Specific monitor")]

            Component.onCompleted: currentIndex = page.monitorModeIndex()

            onActivated: {
                page.cfg_monitorSelectionMode = currentIndex === 1 ? "follow-mouse"
                    : currentIndex === 2 ? "specific"
                    : "widget"

                if (page.cfg_monitorSelectionMode === "specific"
                    && !page.cfg_targetMonitorName
                    && page.availableScreenNames.length > 0) {
                    page.cfg_targetMonitorName = page.availableScreenNames[0]
                }
            }
        }

        ComboBox {
            id: targetMonitorCombo
            Kirigami.FormData.label: i18n("Specific monitor:")
            Layout.fillWidth: true
            visible: page.cfg_monitorSelectionMode === "specific"
            model: page.availableScreenNames

            Component.onCompleted: currentIndex = Math.max(0, page.targetMonitorIndex())

            onVisibleChanged: {
                if (visible) {
                    currentIndex = Math.max(0, page.targetMonitorIndex())
                }
            }

            onActivated: {
                if (currentIndex >= 0 && currentIndex < page.availableScreenNames.length) {
                    page.cfg_targetMonitorName = page.availableScreenNames[currentIndex]
                }
            }
        }

        CheckBox {
            id: showOnlyCurrentMonitor
            text: i18n("Show only open windows from the current monitor")
        }

        CheckBox {
            id: showOnlyCurrentVirtualDesktop
            text: i18n("Show only open windows from the current virtual desktop")
        }

        CheckBox {
            id: enableFullscreen
            text: i18n("Enable fullscreen mode")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Widget icon:")
            spacing: Kirigami.Units.smallSpacing

            Button {
                id: iconButton
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                Layout.preferredHeight: Layout.preferredWidth
                onClicked: iconDialog.open()

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.large
                    height: width
                    source: page.cfg_widgetIcon || "view-grid"
                }
            }

            Button {
                text: i18n("Choose…")
                onClicked: iconDialog.open()
            }

            Button {
                text: i18n("Reset")
                onClicked: page.cfg_widgetIcon = "view-grid"
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Cursor border color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                Layout.preferredHeight: Layout.preferredWidth
                radius: Kirigami.Units.cornerRadius
                color: page.cfg_cursorBorderColor || "#7dcfff"
                border.color: Kirigami.Theme.textColor
                border.width: 1
            }

            TextField {
                id: cursorBorderColorField
                Layout.fillWidth: true
                placeholderText: "#7dcfff"
            }

            Button {
                text: i18n("Choose…")
                onClicked: colorDialog.open()
            }

            Button {
                text: i18n("Reset")
                onClicked: page.cfg_cursorBorderColor = "#7dcfff"
            }
        }

        Button {
            text: i18n("Reset layout")
            onClicked: {
                page.cfg_dashboardLayout = "default"
                layoutTypeCombo.currentIndex = 0
            }
        }
    }
}
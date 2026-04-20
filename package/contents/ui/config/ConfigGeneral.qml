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
    property alias cfg_cursorBorderColor: cursorBorderColorField.text

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
    }
}
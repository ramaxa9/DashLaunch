import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.iconthemes as KIconThemes
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property string cfg_widgetIcon: ""

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: iconName => page.cfg_widgetIcon = iconName || "view-grid"
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
    }
}
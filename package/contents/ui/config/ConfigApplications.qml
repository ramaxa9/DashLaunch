import QtQuick
import QtQuick.Controls

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_showOnlyCurrentMonitor: showOnlyCurrentMonitor.checked
    property alias cfg_showOnlyCurrentVirtualDesktop: showOnlyCurrentVirtualDesktop.checked

    Kirigami.FormLayout {
        CheckBox {
            id: showOnlyCurrentMonitor
            text: i18n("Show only open windows from the current monitor")
        }

        CheckBox {
            id: showOnlyCurrentVirtualDesktop
            text: i18n("Show only open windows from the current virtual desktop")
        }
    }
}
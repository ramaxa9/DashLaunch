import QtQuick
import QtQuick.Controls

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_showOnlyCurrentMonitor: showOnlyCurrentMonitor.checked

    Kirigami.FormLayout {
        CheckBox {
            id: showOnlyCurrentMonitor
            text: i18n("Show only open windows from the current monitor")
        }
    }
}
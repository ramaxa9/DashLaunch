import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Settings")
        icon: "configure"
        source: "config/ConfigGeneral.qml"
    }

    ConfigCategory {
        name: i18n("Help")
        icon: "help-contents"
        source: "config/ConfigHelp.qml"
    }
}
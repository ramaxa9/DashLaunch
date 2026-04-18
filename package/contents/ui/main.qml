pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property color panelColor: Qt.rgba(0.05, 0.06, 0.08, 0.96)
    readonly property color surfaceColor: Qt.rgba(1, 1, 1, 0.06)
    readonly property color surfaceHoverColor: Qt.rgba(1, 1, 1, 0.11)
    readonly property color borderColor: Qt.rgba(1, 1, 1, 0.08)
    readonly property color accentColor: "#d5a64a"
    readonly property color textColor: "#f5f2eb"
    readonly property color mutedTextColor: Qt.rgba(0.96, 0.94, 0.9, 0.68)
    readonly property int tilePadding: 12

    property string searchText: ""
    property rect currentScreenGeometry: Qt.rect(0, 0, Screen.width, Screen.height)
    property int selectedSearchIndex: 0
    property int selectedWindowIndex: -1
    property int windowGridColumns: 1

    readonly property bool searching: searchText.length > 0
    readonly property bool filterCurrentMonitor: Plasmoid.configuration.showOnlyCurrentMonitor
    readonly property var searchResultsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

    Plasmoid.title: "Dash Launch"
    Plasmoid.icon: Plasmoid.configuration.widgetIcon || "view-grid"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: compactRepresentation
    switchWidth: Math.round(root.currentScreenGeometry.width * 0.95)
    switchHeight: Math.round(root.currentScreenGeometry.height * 0.95)

    function clearSearch() {
        searchText = "";
        selectedSearchIndex = 0;
    }

    function closeDashboard() {
        root.expanded = false;
        clearSearch();
        selectedWindowIndex = -1;
    }

    function expandedWindow() {
        const item = root.fullRepresentationItem;
        return item && item.Window ? item.Window.window : null;
    }

    function updateCurrentScreenGeometry(screen) {
        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            return;
        }

        const activeScreen = screen || (root.expandedWindow() ? root.expandedWindow().screen : null) || screens[0];
        const sx = activeScreen.virtualX !== undefined ? activeScreen.virtualX : 0;
        const sy = activeScreen.virtualY !== undefined ? activeScreen.virtualY : 0;
        currentScreenGeometry = Qt.rect(sx, sy, activeScreen.width, activeScreen.height);
        windowsModel.screenGeometry = currentScreenGeometry;
    }

    function syncWindowSelection() {
        if (windowsModel.count <= 0) {
            selectedWindowIndex = -1;
            return;
        }

        if (selectedWindowIndex < 0 || selectedWindowIndex >= windowsModel.count) {
            selectedWindowIndex = 0;
        }
    }

    function taskIndex(row) {
        return windowsModel.index(row, 0);
    }

    function taskData(row, role) {
        return windowsModel.data(taskIndex(row), role);
    }

    function taskAppName(row) {
        return taskData(row, TaskManager.AbstractTasksModel.AppName) || "Application";
    }

    function activateWindow(row) {
        const index = taskIndex(row);
        if (!index.valid) {
            return;
        }

        if (taskData(row, TaskManager.AbstractTasksModel.IsMinimized)) {
            windowsModel.requestToggleMinimized(index);
        }

        windowsModel.requestActivate(index);
        closeDashboard();
    }

    function closeWindow(row) {
        const index = taskIndex(row);
        if (!index.valid) {
            return;
        }

        windowsModel.requestClose(index);

        if (windowsModel.count <= 1) {
            selectedWindowIndex = -1;
            return;
        }

        selectedWindowIndex = Math.max(0, Math.min(windowsModel.count - 2, row));
    }

    function moveSearchSelection(step) {
        const count = searchResultsModel ? searchResultsModel.count : 0;
        if (count <= 0) {
            return;
        }

        selectedSearchIndex = Math.max(0, Math.min(count - 1, selectedSearchIndex + step));
    }

    function moveWindowSelectionHorizontal(step) {
        if (windowsModel.count <= 0) {
            return;
        }

        syncWindowSelection();
        selectedWindowIndex = Math.max(0, Math.min(windowsModel.count - 1, selectedWindowIndex + step));
    }

    function moveWindowSelectionVertical(step) {
        if (windowsModel.count <= 0) {
            return;
        }

        syncWindowSelection();

        const columns = Math.max(1, windowGridColumns);
        const currentColumn = selectedWindowIndex % columns;
        const currentRow = Math.floor(selectedWindowIndex / columns);
        const targetRow = Math.max(0, currentRow + step);
        const targetIndex = (targetRow * columns) + currentColumn;
        selectedWindowIndex = Math.max(0, Math.min(windowsModel.count - 1, targetIndex));
    }

    function triggerSelectedSearchResult() {
        const count = searchResultsModel ? searchResultsModel.count : 0;
        if (count <= 0) {
            return false;
        }

        searchResultsModel.trigger(selectedSearchIndex, "", null);
        closeDashboard();
        return true;
    }

    function triggerPrimaryAction() {
        if (searching) {
            return triggerSelectedSearchResult();
        }

        if (selectedWindowIndex >= 0) {
            activateWindow(selectedWindowIndex);
            return true;
        }

        return false;
    }

    function handleNavigationKey(event) {
        if ((event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0) {
            return false;
        }

        if (event.key === Qt.Key_Up) {
            if (searching) {
                moveSearchSelection(-1);
            } else {
                moveWindowSelectionVertical(-1);
            }
            event.accepted = true;
            return true;
        }

        if (event.key === Qt.Key_Down) {
            if (searching) {
                moveSearchSelection(1);
            } else {
                moveWindowSelectionVertical(1);
            }
            event.accepted = true;
            return true;
        }

        if (!searching && event.key === Qt.Key_Left) {
            moveWindowSelectionHorizontal(-1);
            event.accepted = true;
            return true;
        }

        if (!searching && event.key === Qt.Key_Right) {
            moveWindowSelectionHorizontal(1);
            event.accepted = true;
            return true;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = triggerPrimaryAction();
            return event.accepted;
        }

        if (!searching && event.key === Qt.Key_Delete && selectedWindowIndex >= 0) {
            closeWindow(selectedWindowIndex);
            event.accepted = true;
            return true;
        }

        return false;
    }

    onExpandedChanged: {
            if (!root.expanded) {
            clearSearch();
            return;
        }

        updateCurrentScreenGeometry();
        windowsModel.sort(0);
        windowsModel.invalidate();
        syncWindowSelection();
        Qt.callLater(updateCurrentScreenGeometry);
    }

    onFullRepresentationItemChanged: {
        if (expanded) {
            Qt.callLater(updateCurrentScreenGeometry);
        }
    }

    onSearchTextChanged: {
        selectedSearchIndex = 0;
        if (!searching && searchField.activeFocus) {
            fullView.forceActiveFocus();
        }
    }

    Component.onCompleted: updateCurrentScreenGeometry()

    Kicker.RunnerModel {
        id: runnerModel
        mergeResults: true
        runners: ["krunner_services"]
        query: root.searchText
    }

    TaskManager.TasksModel {
        id: windowsModel
        activity: ""
        filterByVirtualDesktop: true
        filterByScreen: root.filterCurrentMonitor
        screenGeometry: root.currentScreenGeometry
        groupInline: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        hideActivatedLaunchers: true
        sortMode: TaskManager.TasksModel.SortLastActivated

        onCountChanged: root.syncWindowSelection()
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 3
        implicitHeight: Kirigami.Units.gridUnit * 3

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: root.expanded ? root.surfaceHoverColor : root.surfaceColor
            border.color: root.expanded ? root.accentColor : root.borderColor

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.medium
                height: width
                source: Plasmoid.icon
                color: root.textColor
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: FocusScope {
        id: fullView
        focus: root.expanded
        implicitWidth: root.switchWidth
        implicitHeight: root.switchHeight

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 1.4
            color: root.panelColor
            border.color: root.borderColor
        }

        Keys.onEscapePressed: event => {
            root.closeDashboard();
            event.accepted = true;
        }

        Keys.onPressed: event => {
            if (root.handleNavigationKey(event)) {
                return;
            }

            if (searchField.activeFocus) {
                return;
            }

            if ((event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0) {
                return;
            }

            if (event.text && event.text.length > 0) {
                root.searchText += event.text;
                Qt.callLater(function() {
                    searchField.forceActiveFocus();
                });
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    visible: root.searching
                    Layout.preferredWidth: root.searching ? Math.max(280, parent.width * 0.32) : 0
                    Layout.maximumWidth: root.searching ? Math.max(320, parent.width * 0.36) : 0
                    Layout.fillHeight: true
                    radius: Kirigami.Units.cornerRadius
                    color: root.surfaceColor
                    border.color: root.borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.TextField {
                            id: searchField
                            Layout.fillWidth: true
                            text: root.searchText
                            color: root.textColor
                            placeholderText: i18n("Search applications")
                            selectByMouse: true

                            onTextEdited: root.searchText = text

                            background: Rectangle {
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: searchField.activeFocus ? root.accentColor : root.borderColor
                                border.width: 1
                            }

                            leftPadding: Kirigami.Units.largeSpacing
                            rightPadding: Kirigami.Units.largeSpacing
                            topPadding: Kirigami.Units.smallSpacing * 1.5
                            bottomPadding: Kirigami.Units.smallSpacing * 1.5

                            Keys.onPressed: event => {
                                root.handleNavigationKey(event);
                            }

                            Keys.onEscapePressed: event => {
                                if (text.length > 0) {
                                    root.clearSearch();
                                } else {
                                    root.closeDashboard();
                                }
                                event.accepted = true;
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Kirigami.Units.smallSpacing
                            model: root.searchResultsModel
                            currentIndex: root.selectedSearchIndex

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    positionViewAtIndex(currentIndex, ListView.Contain);
                                }
                            }

                            delegate: Rectangle {
                                required property int index
                                required property var model

                                width: ListView.view.width
                                height: Kirigami.Units.gridUnit * 3.4
                                radius: Kirigami.Units.cornerRadius
                                color: resultMouseArea.containsMouse || root.selectedSearchIndex === index ? root.surfaceHoverColor : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.largeSpacing

                                    Kirigami.Icon {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                        Layout.preferredHeight: width
                                        source: model.decoration
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            color: root.textColor
                                            elide: Text.ElideRight
                                            text: model.display
                                        }

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            color: root.mutedTextColor
                                            elide: Text.ElideRight
                                            text: model.description || i18n("Launch application")
                                        }
                                    }
                                }

                                MouseArea {
                                    id: resultMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedSearchIndex = index;
                                        root.triggerSelectedSearchResult();
                                    }
                                }
                            }

                            footer: Item {
                                width: ListView.view.width
                                height: root.searching && (!root.searchResultsModel || root.searchResultsModel.count === 0) ? Kirigami.Units.gridUnit * 4 : 0

                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    color: root.mutedTextColor
                                    text: i18n("Nothing found")
                                    visible: parent.height > 0
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Kirigami.Units.cornerRadius
                    color: root.surfaceColor
                    border.color: root.borderColor

                    QQC2.ScrollView {
                        anchors.fill: parent
                        clip: true
                        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                        GridView {
                            id: windowsGrid
                            anchors.fill: parent
                            anchors.margins: root.tilePadding
                            model: windowsModel
                            currentIndex: root.selectedWindowIndex
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            cellWidth: Math.max(220, Math.min(320, width / Math.max(1, root.windowGridColumns)))
                            cellHeight: cellWidth * 0.68

                            function updateColumns() {
                                const idealWidth = root.searching ? 260 : 280;
                                root.windowGridColumns = Math.max(1, Math.floor(Math.max(width, idealWidth) / idealWidth));
                            }

                            onWidthChanged: updateColumns()
                            Component.onCompleted: updateColumns()

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    positionViewAtIndex(currentIndex, GridView.Contain);
                                }
                            }

                            delegate: Rectangle {
                                required property int index

                                width: windowsGrid.cellWidth - root.tilePadding
                                height: windowsGrid.cellHeight - root.tilePadding
                                radius: Kirigami.Units.cornerRadius
                                color: windowMouseArea.containsMouse || root.selectedWindowIndex === index ? root.surfaceHoverColor : "transparent"
                                border.width: root.selectedWindowIndex === index ? 1.5 : 1
                                border.color: root.selectedWindowIndex === index ? root.accentColor : root.borderColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: root.tilePadding
                                    spacing: Kirigami.Units.smallSpacing

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Kirigami.Icon {
                                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                            Layout.preferredHeight: width
                                            source: root.taskData(index, Qt.DecorationRole)
                                        }

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            color: root.textColor
                                            elide: Text.ElideRight
                                            font.weight: Font.DemiBold
                                            text: root.taskData(index, Qt.DisplayRole) || root.taskAppName(index)
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Kirigami.Units.cornerRadius
                                            color: Qt.rgba(1, 1, 1, 0.04)
                                            border.color: Qt.rgba(1, 1, 1, 0.04)
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                                width: parent.width - Kirigami.Units.largeSpacing * 2
                                            spacing: Kirigami.Units.smallSpacing

                                            Kirigami.Icon {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                    width: parent.parent.height * 0.8
                                                height: width
                                                source: root.taskData(index, Qt.DecorationRole)
                                            }

                                            PlasmaComponents3.Label {
                                                width: parent.width
                                                horizontalAlignment: Text.AlignHCenter
                                                color: root.mutedTextColor
                                                elide: Text.ElideRight
                                                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.95)
                                                text: root.taskAppName(index)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: windowMouseArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        root.selectedWindowIndex = index;

                                        if (mouse.button === Qt.MiddleButton) {
                                            root.closeWindow(index);
                                            return;
                                        }

                                        root.activateWindow(index);
                                    }
                                }
                            }

                            PlasmaComponents3.Label {
                                anchors.centerIn: parent
                                color: root.mutedTextColor
                                text: root.filterCurrentMonitor ? i18n("No open windows on current monitor") : i18n("No open windows")
                                visible: windowsModel.count === 0
                            }
                        }
                    }
                }
            }
        }
    }
}

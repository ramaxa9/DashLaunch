pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    readonly property color cardColor: Qt.rgba(1, 1, 1, 0.08)
    readonly property color cardHoverColor: Qt.rgba(1, 1, 1, 0.14)
    readonly property color accentColor: "#d5a64a"
    readonly property color textColor: "#f5f2eb"
    readonly property color mutedTextColor: Qt.rgba(0.96, 0.94, 0.9, 0.68)
    readonly property int tilePadding: 10

    property string searchText: ""
    property rect currentScreenGeometry: Qt.rect(0, 0, Screen.width, Screen.height)
    property var selectedWindowId: null
    property int selectedSearchIndex: 0
    property var windowNavigationIds: []
    property int windowGridColumns: 1
    readonly property int selectedWindowModelIndex: selectedWindowId === null ? -1 : rowForWindowId(selectedWindowId)

    readonly property bool searching: searchText.length > 0
    readonly property var searchResultsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

    Plasmoid.title: "Dash Launch"
    Plasmoid.icon: Plasmoid.configuration.widgetIcon || "view-grid"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: compactRepresentation
    switchWidth: Math.max(960, root.currentScreenGeometry.width)
    switchHeight: Math.max(640, root.currentScreenGeometry.height)

    function clearSearch() {
        searchText = "";
        selectedSearchIndex = 0;
    }

    function closeDashboard() {
        root.expanded = false;
        clearSearch();
        selectedWindowId = null;
        windowNavigationIds = [];
    }

    function expandedWindow() {
        const item = root.fullRepresentationItem;
        return item && item.Window ? item.Window.window : null;
    }

    function ensureWindowGeometry() {
        if (!root.expanded) {
            return;
        }

        const window = root.expandedWindow();
        if (!window) {
            Qt.callLater(root.ensureWindowGeometry);
            return;
        }

        root.updateCurrentScreenGeometry(window.screen);

        window.visibility = Window.FullScreen;
        window.x = root.currentScreenGeometry.x;
        window.y = root.currentScreenGeometry.y;
        window.width = root.currentScreenGeometry.width;
        window.height = root.currentScreenGeometry.height;

        window.raise();
        window.requestActivate();
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

    function taskIndex(row) {
        return windowsModel.index(row, 0);
    }

    function taskData(row, role) {
        return windowsModel.data(taskIndex(row), role);
    }

    function taskAppName(row) {
        return taskData(row, TaskManager.AbstractTasksModel.AppName) || "Application";
    }

    function taskWindowId(row) {
        const ids = taskData(row, TaskManager.AbstractTasksModel.WinIdList);
        return ids && ids.length ? ids[0] : null;
    }

    function rowForWindowId(windowId) {
        if (windowId === null || windowId === undefined) {
            return -1;
        }
        for (let row = 0; row < windowsModel.count; ++row) {
            if (taskWindowId(row) === windowId) {
                return row;
            }
        }
        return -1;
    }

    function raiseWindowById(windowId) {
        const row = rowForWindowId(windowId);
        if (row < 0) {
            return;
        }
        const index = taskIndex(row);
        if (!index.valid) {
            return;
        }

        if (taskData(row, TaskManager.AbstractTasksModel.IsMinimized)) {
            windowsModel.requestToggleMinimized(index);
        }

        Qt.callLater(function() {
            const refreshedRow = rowForWindowId(windowId);
            if (refreshedRow < 0) {
                return;
            }
            const refreshedIndex = taskIndex(refreshedRow);
            if (!refreshedIndex.valid) {
                return;
            }
            windowsModel.requestActivate(refreshedIndex);
            closeDashboard();
        });
    }

    function closeWindowById(windowId) {
        const row = rowForWindowId(windowId);
        if (row < 0) {
            return;
        }
        const index = taskIndex(row);
        if (!index.valid) {
            return;
        }
        windowsModel.requestClose(index);
        closeDashboard();
    }

    function navigationIndexForWindowId(windowId) {
        return windowNavigationIds.indexOf(windowId);
    }

    function selectedWindowNavigationIndex() {
        return Math.max(0, navigationIndexForWindowId(selectedWindowId));
    }

    function setSelectedWindowId(windowId) {
        if (windowId === null || windowId === undefined) {
            selectedWindowId = null;
            return;
        }
        selectedWindowId = windowId;
    }

    function rebuildWindowNavigation() {
        const previousWindowId = selectedWindowId;
        const ids = [];

        for (let row = 0; row < windowsModel.count; ++row) {
            const windowId = taskWindowId(row);
            if (windowId !== null && windowId !== undefined) {
                ids.push(windowId);
            }
        }

        windowNavigationIds = ids;

        if (ids.length === 0) {
            selectedWindowId = null;
            return;
        }

        if (previousWindowId !== null && ids.indexOf(previousWindowId) >= 0) {
            selectedWindowId = previousWindowId;
            return;
        }

        selectedWindowId = ids[0];
    }

    function refreshWindowGridOnOpen() {
        windowsModel.sort(0);
        windowsModel.invalidate();

        Qt.callLater(function() {
            root.rebuildWindowNavigation();

            if (typeof windowsGrid !== "undefined") {
                windowsGrid.positionViewAtBeginning();
                windowsGrid.forceLayout();
            }
        });
    }

    function setSelectedWindowNavigationIndex(index) {
        if (windowNavigationIds.length <= 0) {
            selectedWindowId = null;
            return;
        }

        const nextIndex = Math.max(0, Math.min(windowNavigationIds.length - 1, index));
        selectedWindowId = windowNavigationIds[nextIndex];
    }

    function moveWindowSelectionVertical(step) {
        if (windowNavigationIds.length <= 0) {
            return;
        }

        const columns = Math.max(1, windowGridColumns);
        const currentIndex = selectedWindowNavigationIndex();
        const currentColumn = currentIndex % columns;
        const currentRow = Math.floor(currentIndex / columns);
        const maxRow = Math.floor((windowNavigationIds.length - 1) / columns);
        const nextRow = Math.max(0, Math.min(maxRow, currentRow + step));
        const firstIndexInRow = nextRow * columns;
        const lastIndexInRow = Math.min(windowNavigationIds.length - 1, firstIndexInRow + columns - 1);
        const nextIndex = Math.min(lastIndexInRow, firstIndexInRow + currentColumn);

        setSelectedWindowNavigationIndex(nextIndex);
    }

    function moveWindowSelectionHorizontal(step) {
        if (windowNavigationIds.length <= 0) {
            return;
        }

        const currentIndex = selectedWindowNavigationIndex();
        setSelectedWindowNavigationIndex(currentIndex + step);
    }

    function moveSearchSelection(step) {
        const count = searchResultsModel ? searchResultsModel.count : 0;
        if (count <= 0) {
            return;
        }
        selectedSearchIndex = Math.max(0, Math.min(count - 1, selectedSearchIndex + step));
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
        if (searching && triggerSelectedSearchResult()) {
            return true;
        }
        if (windowNavigationIds.length > 0) {
            raiseWindowById(selectedWindowId !== null ? selectedWindowId : windowNavigationIds[0]);
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
            if (triggerPrimaryAction()) {
                event.accepted = true;
                return true;
            }
        }

        if (searchText.length === 0 && event.key === Qt.Key_Delete && selectedWindowId !== null) {
            closeWindowById(selectedWindowId);
            event.accepted = true;
            return true;
        }

        return false;
    }

    onExpandedChanged: function() {
        if (root.expanded) {
            root.updateCurrentScreenGeometry();
            root.clearSearch();
            root.selectedSearchIndex = 0;
            root.refreshWindowGridOnOpen();
            Qt.callLater(root.ensureWindowGeometry);
        } else {
            root.clearSearch();
        }
    }

    onFullRepresentationItemChanged: {
        if (root.expanded) {
            Qt.callLater(root.ensureWindowGeometry);
        }
    }

    onSearchTextChanged: selectedSearchIndex = 0

    Component.onCompleted: {
        root.updateCurrentScreenGeometry();
    }

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
        filterByScreen: Plasmoid.configuration.showOnlyCurrentMonitor
        screenGeometry: root.currentScreenGeometry
        groupInline: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        hideActivatedLaunchers: true
        sortMode: TaskManager.TasksModel.SortLastActivated

        onCountChanged: {
            if (root.expanded) {
                root.rebuildWindowNavigation();
            } else if (count <= 0) {
                root.selectedWindowId = null;
                root.windowNavigationIds = [];
            }
        }
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 3
        implicitHeight: Kirigami.Units.gridUnit * 3

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: root.expanded ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
            border.color: root.expanded ? root.accentColor : Qt.rgba(1, 1, 1, 0.1)

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

    fullRepresentation: Item {
        implicitWidth: root.switchWidth
        implicitHeight: root.switchHeight

        FocusScope {
            anchors.fill: parent
            focus: root.expanded

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.03, 0.04, 0.06, 0.95)
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
                    searchField.forceActiveFocus();
                    root.searchText += event.text;
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.tilePadding
                spacing: Kirigami.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        visible: root.searching
                        Layout.preferredWidth: parent.width * 0.2
                        Layout.maximumWidth: parent.width * 0.2
                        Layout.fillHeight: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.TextField {
                            id: searchField
                            Layout.fillWidth: true
                            text: root.searchText
                            color: root.textColor
                            font.pixelSize: Kirigami.Units.gridUnit
                            placeholderText: "Search applications"
                            selectByMouse: true

                            onTextEdited: root.searchText = text

                            background: Rectangle {
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: searchField.activeFocus ? root.accentColor : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1
                            }

                            leftPadding: Kirigami.Units.largeSpacing
                            rightPadding: Kirigami.Units.largeSpacing
                            topPadding: Kirigami.Units.smallSpacing * 1.5
                            bottomPadding: Kirigami.Units.smallSpacing * 1.5

                            Keys.onEscapePressed: event => {
                                if (text.length > 0) {
                                    root.clearSearch();
                                } else {
                                    root.closeDashboard();
                                }
                                event.accepted = true;
                            }

                            Keys.onPressed: event => {
                                root.handleNavigationKey(event);
                            }

                            Keys.onReturnPressed: event => {
                                event.accepted = root.triggerPrimaryAction();
                            }

                            Keys.onEnterPressed: event => {
                                event.accepted = root.triggerPrimaryAction();
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                            }

                            Loader {
                                anchors.fill: parent
                                active: root.searchResultsModel !== null
                                sourceComponent: Component {
                                    ListView {
                                        id: searchResultsList
                                        anchors.fill: parent
                                        anchors.margins: Kirigami.Units.smallSpacing
                                        clip: true
                                        model: root.searchResultsModel
                                        currentIndex: root.selectedSearchIndex
                                        spacing: Kirigami.Units.smallSpacing

                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0) {
                                                positionViewAtIndex(currentIndex, ListView.Contain);
                                            }
                                        }

                                        delegate: Rectangle {
                                            required property int index
                                            required property var model

                                            width: ListView.view.width
                                            height: Kirigami.Units.gridUnit * 3.6
                                            radius: Kirigami.Units.cornerRadius
                                            color: (root.selectedSearchIndex === index || resultMouseArea.containsMouse) ? root.cardHoverColor : "transparent"
                                            border.color: Qt.rgba(1, 1, 1, 0.06)

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: Kirigami.Units.smallSpacing
                                                spacing: Kirigami.Units.largeSpacing

                                                Kirigami.Icon {
                                                    Layout.alignment: Qt.AlignVCenter
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
                                                        text: model.description || "Launch application"
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
                                                    root.searchResultsModel.trigger(index, "", null);
                                                    root.closeDashboard();
                                                }
                                            }
                                        }

                                        footer: Item {
                                            width: ListView.view.width
                                            height: root.searchResultsModel && root.searchResultsModel.count === 0 ? Kirigami.Units.gridUnit * 4 : 0

                                            PlasmaComponents3.Label {
                                                anchors.centerIn: parent
                                                color: root.mutedTextColor
                                                text: "Nothing found"
                                                visible: parent.height > 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: windowsSection
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: root.tilePadding
                        spacing: Kirigami.Units.smallSpacing

                        property real previewAspect: 16 / 9
                        property real baseWidthByCount: (1920 * 0.9) / Math.max(1, windowsModel.count)
                        property real unclampedWidth: Math.max(200, Math.min(400, baseWidthByCount))

                        QQC2.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                            GridView {
                                id: windowsGrid
                                anchors.fill: parent
                                model: windowsModel
                                currentIndex: root.selectedWindowModelIndex
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true
                                interactive: true
                                cellWidth: windowsSection.unclampedWidth + root.tilePadding
                                cellHeight: Math.round((windowsSection.unclampedWidth / windowsSection.previewAspect) + Kirigami.Units.gridUnit * 4.2) + root.tilePadding
                                leftMargin: root.tilePadding
                                rightMargin: root.tilePadding
                                topMargin: root.tilePadding
                                bottomMargin: root.tilePadding

                                function updateColumns() {
                                    root.windowGridColumns = Math.max(1, Math.floor(width / cellWidth));
                                }

                                onWidthChanged: updateColumns()
                                onCellWidthChanged: updateColumns()

                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0) {
                                        positionViewAtIndex(currentIndex, GridView.Contain);
                                    }
                                }

                                delegate: Rectangle {
                                    required property int index

                                    property var currentWindowId: root.taskWindowId(index)

                                    width: windowsGrid.cellWidth - root.tilePadding
                                    height: windowsGrid.cellHeight - root.tilePadding
                                    radius: Kirigami.Units.cornerRadius
                                    color: windowMouseArea.containsMouse ? root.cardHoverColor : root.cardColor
                                    border.width: root.selectedWindowId === currentWindowId ? 1.5 : 1
                                    border.color: root.selectedWindowId === currentWindowId ? root.accentColor : Qt.rgba(1, 1, 1, 0.08)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: root.tilePadding
                                        spacing: root.tilePadding

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
                                                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.72)
                                                font.weight: Font.DemiBold
                                                text: root.taskData(index, Qt.DisplayRole) || root.taskAppName(index)
                                            }

                                        }

                                        Item {
                                            id: previewHost
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.round(width / windowsSection.previewAspect)
                                            clip: true

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Kirigami.Units.cornerRadius
                                                color: Qt.rgba(1, 1, 1, 0.04)
                                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                width: Math.min(parent.width - Kirigami.Units.largeSpacing * 2, Math.max(parent.width * 0.68, Kirigami.Units.gridUnit * 6))
                                                spacing: Kirigami.Units.smallSpacing

                                                Kirigami.Icon {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: Math.min(previewHost.width, previewHost.height) * 0.5
                                                    height: width
                                                    source: root.taskData(index, Qt.DecorationRole)
                                                }

                                                PlasmaComponents3.Label {
                                                    width: parent.width
                                                    horizontalAlignment: Text.AlignHCenter
                                                    color: root.mutedTextColor
                                                    elide: Text.ElideRight
                                                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.82)
                                                    maximumLineCount: 1
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
                                            root.setSelectedWindowId(currentWindowId);

                                            if (mouse.button === Qt.MiddleButton) {
                                                root.closeWindowById(currentWindowId);
                                                return;
                                            }

                                            root.raiseWindowById(currentWindowId);
                                        }
                                    }
                                }

                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    color: root.mutedTextColor
                                    text: Plasmoid.configuration.showOnlyCurrentMonitor ? "No open windows on current monitor" : "No open windows"
                                    visible: windowsModel.count === 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
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
    property int selectedDesktopIndex: -1
    property int windowGridColumns: 1
    readonly property int desktopPreviewWidth: 400
    readonly property int desktopPreviewHeight: currentScreenGeometry.width > 0
        ? Math.round(desktopPreviewWidth * currentScreenGeometry.height / currentScreenGeometry.width)
        : 225
    property int desktopPreviewRevision: 0
    property bool pendingInitialWindowFocus: false
    property bool suppressHoverSelectionOnOpen: false
    property string navigationSection: "desktops"

    readonly property bool searching: searchText.length > 0
    readonly property bool filterCurrentMonitor: Plasmoid.configuration.showOnlyCurrentMonitor
    readonly property var searchResultsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

    Plasmoid.title: "Dash Launch"
    Plasmoid.icon: Plasmoid.configuration.widgetIcon || "view-grid"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: compactRepresentation
    switchWidth: root.currentScreenGeometry.width
    switchHeight: root.currentScreenGeometry.height

    function clearSearch() {
        searchText = "";
        selectedSearchIndex = 0;
    }

    function closeDashboard() {
        root.expanded = false;
        clearSearch();
        selectedWindowIndex = -1;
        selectedDesktopIndex = -1;
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

    function syncDesktopSelection() {
        const desktopIds = virtualDesktopInfo.desktopIds || [];
        if (desktopIds.length <= 0) {
            selectedDesktopIndex = -1;
            if (navigationSection === "desktops") {
                navigationSection = "windows";
            }
            return;
        }

        const currentDesktopIndex = desktopIds.indexOf(virtualDesktopInfo.currentDesktop);
        if (selectedDesktopIndex < 0 || selectedDesktopIndex >= desktopIds.length) {
            selectedDesktopIndex = Math.max(0, currentDesktopIndex);
        }
    }

    function taskIndex(row) {
        return windowsModel.index(row, 0);
    }

    function taskData(row, role) {
        return windowsModel.data(taskIndex(row), role);
    }

    function desktopTaskIndex(row) {
        return desktopWindowsModel.index(row, 0);
    }

    function desktopTaskData(row, role) {
        return desktopWindowsModel.data(desktopTaskIndex(row), role);
    }

    function desktopIdAt(index) {
        const desktopIds = virtualDesktopInfo.desktopIds || [];
        if (index < 0 || index >= desktopIds.length) {
            return "";
        }

        return desktopIds[index];
    }

    function taskAppName(row) {
        return taskData(row, TaskManager.AbstractTasksModel.AppName) || "Application";
    }

    function desktopName(desktopId) {
        const ids = virtualDesktopInfo.desktopIds || [];
        const names = virtualDesktopInfo.desktopNames || [];
        const index = ids.indexOf(desktopId);
        if (index >= 0 && index < names.length) {
            return names[index];
        }

        return i18n("Desktop");
    }

    function desktopIndex(desktopId) {
        return (virtualDesktopInfo.desktopIds || []).indexOf(desktopId);
    }

    function intersectRects(first, second) {
        const left = Math.max(first.x, second.x);
        const top = Math.max(first.y, second.y);
        const right = Math.min(first.x + first.width, second.x + second.width);
        const bottom = Math.min(first.y + first.height, second.y + second.height);

        if (right <= left || bottom <= top) {
            return Qt.rect(0, 0, 0, 0);
        }

        return Qt.rect(left, top, right - left, bottom - top);
    }

    function taskBelongsToDesktop(row, desktopId) {
        if (desktopTaskData(row, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops)) {
            return true;
        }

        const desktopIds = desktopTaskData(row, TaskManager.AbstractTasksModel.VirtualDesktops) || [];
        return desktopIds.indexOf(desktopId) >= 0;
    }

    function desktopWindowIndexes(desktopId) {
        const indexes = [];

        for (let row = 0; row < desktopWindowsModel.count; ++row) {
            const geometry = desktopTaskData(row, TaskManager.AbstractTasksModel.Geometry);
            const clippedGeometry = intersectRects(geometry, currentScreenGeometry);

            if (clippedGeometry.width <= 0 || clippedGeometry.height <= 0) {
                continue;
            }

            if (taskBelongsToDesktop(row, desktopId)) {
                indexes.push(row);
            }
        }

        return indexes;
    }

    function desktopWindowCount(desktopId) {
        return desktopWindowIndexes(desktopId).length;
    }

    function refreshDesktopPreviews() {
        desktopPreviewRevision += 1;
    }

    function desktopWindowPreviewRect(row, previewWidth, previewHeight) {
        const geometry = desktopTaskData(row, TaskManager.AbstractTasksModel.Geometry);
        const clippedGeometry = intersectRects(geometry, currentScreenGeometry);

        if (clippedGeometry.width <= 0 || clippedGeometry.height <= 0 || currentScreenGeometry.width <= 0 || currentScreenGeometry.height <= 0) {
            return Qt.rect(0, 0, 0, 0);
        }

        const localX = clippedGeometry.x - currentScreenGeometry.x;
        const localY = clippedGeometry.y - currentScreenGeometry.y;
        const scaleX = previewWidth / currentScreenGeometry.width;
        const scaleY = previewHeight / currentScreenGeometry.height;

        return Qt.rect(
            Math.round(localX * scaleX),
            Math.round(localY * scaleY),
            Math.max(10, Math.round(clippedGeometry.width * scaleX)),
            Math.max(8, Math.round(clippedGeometry.height * scaleY))
        );
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

        const columns = visibleWindowGridColumns();
        const currentColumn = selectedWindowIndex % columns;
        const currentRow = Math.floor(selectedWindowIndex / columns);
        const targetRow = Math.max(0, currentRow + step);
        const targetIndex = (targetRow * columns) + currentColumn;
        selectedWindowIndex = Math.max(0, Math.min(windowsModel.count - 1, targetIndex));
    }

    function moveDesktopSelection(step) {
        const desktopIds = virtualDesktopInfo.desktopIds || [];
        if (desktopIds.length <= 0) {
            return;
        }

        syncDesktopSelection();
        navigationSection = "desktops";
        selectedDesktopIndex = Math.max(0, Math.min(desktopIds.length - 1, selectedDesktopIndex + step));
    }

    function focusDesktopSelection() {
        syncDesktopSelection();
        if (selectedDesktopIndex >= 0) {
            navigationSection = "desktops";
        }
    }

    function focusWindowSelection() {
        syncWindowSelection();
        if (selectedWindowIndex >= 0) {
            navigationSection = "windows";
        }
    }

    function focusInitialSelection() {
        syncWindowSelection();
        if (selectedWindowIndex >= 0) {
            selectedWindowIndex = 0;
            navigationSection = "windows";
            return;
        }

        syncDesktopSelection();
        navigationSection = selectedDesktopIndex >= 0 ? "desktops" : "windows";
    }

    function applyPendingInitialWindowFocus() {
        if (!pendingInitialWindowFocus || !expanded) {
            return;
        }

        focusInitialSelection();
        pendingInitialWindowFocus = false;
    }

    function visibleWindowGridColumns() {
        return Math.max(1, Math.min(windowGridColumns, windowsModel.count || 1));
    }

    function refreshWindowGridLayout() {
        Qt.callLater(function() {
            if (!windowsGrid) {
                return;
            }

            windowsGrid.updateColumns();

            if (windowsGrid.currentIndex >= 0) {
                windowsGrid.positionViewAtIndex(windowsGrid.currentIndex, GridView.Contain);
            }
        });
    }

    function switchToDesktop(desktopId) {
        if (!desktopId) {
            return false;
        }

        const targetIndex = desktopIndex(desktopId);
        if (targetIndex >= 0) {
            selectedDesktopIndex = targetIndex;
        }

        const command = "qdbus6 org.kde.KWin /VirtualDesktopManager org.freedesktop.DBus.Properties.Set org.kde.KWin.VirtualDesktopManager current " + desktopId;
        desktopSwitcher.disconnectSource(command);
        desktopSwitcher.connectSource(command);
        closeDashboard();
        return true;
    }

    function triggerSelectedDesktop() {
        return switchToDesktop(desktopIdAt(selectedDesktopIndex));
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

        if (navigationSection === "desktops" && selectedDesktopIndex >= 0) {
            return triggerSelectedDesktop();
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
            } else if (navigationSection === "windows") {
                syncWindowSelection();
                if (selectedWindowIndex < visibleWindowGridColumns()) {
                    focusDesktopSelection();
                } else {
                    moveWindowSelectionVertical(-1);
                }
            } else {
                moveDesktopSelection(-1);
            }
            event.accepted = true;
            return true;
        }

        if (event.key === Qt.Key_Down) {
            if (searching) {
                moveSearchSelection(1);
            } else if (navigationSection === "desktops") {
                focusWindowSelection();
            } else {
                moveWindowSelectionVertical(1);
            }
            event.accepted = true;
            return true;
        }

        if (!searching && event.key === Qt.Key_Left) {
            if (navigationSection === "desktops") {
                moveDesktopSelection(-1);
            } else {
                moveWindowSelectionHorizontal(-1);
            }
            event.accepted = true;
            return true;
        }

        if (!searching && event.key === Qt.Key_Right) {
            if (navigationSection === "desktops") {
                moveDesktopSelection(1);
            } else {
                moveWindowSelectionHorizontal(1);
            }
            event.accepted = true;
            return true;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = triggerPrimaryAction();
            return event.accepted;
        }

        if (!searching && navigationSection === "windows" && event.key === Qt.Key_Delete && selectedWindowIndex >= 0) {
            closeWindow(selectedWindowIndex);
            event.accepted = true;
            return true;
        }

        return false;
    }

    onExpandedChanged: {
            if (!root.expanded) {
            pendingInitialWindowFocus = false;
            suppressHoverSelectionOnOpen = false;
            clearSearch();
            return;
        }

        pendingInitialWindowFocus = true;
        suppressHoverSelectionOnOpen = true;
        updateCurrentScreenGeometry();
        windowsModel.sort(0);
        windowsModel.invalidate();
        desktopWindowsModel.sort(0);
        desktopWindowsModel.invalidate();
        refreshDesktopPreviews();
        focusInitialSelection();
        Qt.callLater(updateCurrentScreenGeometry);
        Qt.callLater(refreshDesktopPreviews);
        Qt.callLater(applyPendingInitialWindowFocus);
    }

    onFullRepresentationItemChanged: {
        if (expanded) {
            Qt.callLater(updateCurrentScreenGeometry);
        }
    }

    onSearchingChanged: refreshWindowGridLayout()

    onSelectedWindowIndexChanged: {
        if (!windowsGrid) {
            return;
        }

        if (windowsGrid.currentIndex !== selectedWindowIndex) {
            windowsGrid.currentIndex = selectedWindowIndex;
        }
    }

    onSearchTextChanged: {
        selectedSearchIndex = 0;
        if (!searching && searchField.activeFocus) {
            fullView.forceActiveFocus();
        }
    }

    Component.onCompleted: updateCurrentScreenGeometry()

    Connections {
        target: virtualDesktopInfo

        function onCurrentDesktopChanged() {
            root.syncDesktopSelection();
            root.refreshDesktopPreviews();
        }

        function onDesktopIdsChanged() {
            root.syncDesktopSelection();
            root.refreshDesktopPreviews();
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        mergeResults: true
        runners: ["krunner_services"]
        query: root.searchText
    }

    Plasma5Support.DataSource {
        id: desktopSwitcher
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
        }
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
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

        onCountChanged: {
            root.syncWindowSelection();
            root.applyPendingInitialWindowFocus();
        }
    }

    TaskManager.TasksModel {
        id: desktopWindowsModel
        activity: ""
        filterByVirtualDesktop: false
        filterByScreen: true
        screenGeometry: root.currentScreenGeometry
        groupInline: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        hideActivatedLaunchers: true
        sortMode: TaskManager.TasksModel.SortLastActivated

        onCountChanged: root.refreshDesktopPreviews()
    }

    Connections {
        target: desktopWindowsModel

        function onDataChanged() {
            root.refreshDesktopPreviews();
        }

        function onModelReset() {
            root.refreshDesktopPreviews();
        }

        function onRowsInserted() {
            root.refreshDesktopPreviews();
        }

        function onRowsRemoved() {
            root.refreshDesktopPreviews();
        }
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
        width: root.switchWidth
        height: root.switchHeight
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

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            propagateComposedEvents: true

            onPositionChanged: {
                root.suppressHoverSelectionOnOpen = false;
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

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: root.tilePadding
                        spacing: root.tilePadding

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: virtualDesktopInfo.desktopIds.length > 0 ? root.desktopPreviewHeight + (Kirigami.Units.gridUnit * 2.7) : 0
                            visible: virtualDesktopInfo.desktopIds.length > 0

                            QQC2.ScrollView {
                                anchors.fill: parent
                                clip: true
                                QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff

                                ListView {
                                    id: desktopPreviewList
                                    anchors.fill: parent
                                    currentIndex: root.selectedDesktopIndex
                                    spacing: Kirigami.Units.largeSpacing
                                    orientation: ListView.Horizontal
                                    model: virtualDesktopInfo.desktopIds
                                    boundsBehavior: Flickable.StopAtBounds
                                    readonly property real centeredContentWidth: Math.max(0, (count * root.desktopPreviewWidth) + (Math.max(0, count - 1) * spacing))
                                    readonly property real sideMargin: Math.max(0, (width - centeredContentWidth) / 2)
                                    leftMargin: sideMargin
                                    rightMargin: sideMargin

                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0) {
                                            positionViewAtIndex(currentIndex, ListView.Contain);
                                        }
                                    }

                                    delegate: Rectangle {
                                        id: desktopCard
                                        required property int index
                                        required property var modelData
                                        readonly property string desktopId: modelData
                                        readonly property bool isCurrentDesktop: desktopId === virtualDesktopInfo.currentDesktop
                                        readonly property int previewWindowCount: {
                                            root.desktopPreviewRevision;
                                            return root.desktopWindowCount(desktopId);
                                        }
                                        readonly property bool isSelected: !root.searching && root.navigationSection === "desktops" && root.selectedDesktopIndex === index

                                        width: root.desktopPreviewWidth
                                        height: root.desktopPreviewHeight + (Kirigami.Units.gridUnit * 1.8)
                                        radius: Kirigami.Units.cornerRadius
                                        color: desktopMouseArea.containsMouse || isSelected || isCurrentDesktop ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                        border.width: isSelected ? 1.8 : (isCurrentDesktop ? 1.5 : 1)
                                        border.color: isSelected || isCurrentDesktop ? root.accentColor : root.borderColor

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: Kirigami.Units.smallSpacing
                                            spacing: Kirigami.Units.smallSpacing

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: root.desktopPreviewHeight

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: Kirigami.Units.cornerRadius
                                                    color: Qt.rgba(1, 1, 1, 0.035)
                                                    border.color: Qt.rgba(1, 1, 1, isCurrentDesktop ? 0.12 : 0.06)
                                                }

                                                Repeater {
                                                    model: root.expanded
                                                        ? (function() {
                                                            root.desktopPreviewRevision;
                                                            return root.desktopWindowIndexes(desktopCard.desktopId);
                                                        })()
                                                        : []

                                                    delegate: Rectangle {
                                                        required property int modelData
                                                        readonly property rect previewRect: {
                                                            root.desktopPreviewRevision;
                                                            return root.desktopWindowPreviewRect(modelData, parent.width, parent.height);
                                                        }

                                                        x: previewRect.x
                                                        y: previewRect.y
                                                        width: previewRect.width
                                                        height: previewRect.height
                                                        radius: Math.min(Kirigami.Units.cornerRadius, height / 3)
                                                        color: Qt.rgba(1, 1, 1, 0.09)
                                                        border.width: 1
                                                        border.color: Qt.rgba(1, 1, 1, 0.12)

                                                        Kirigami.Icon {
                                                            anchors.centerIn: parent
                                                            width: Math.max(10, Math.min(parent.width - 4, parent.height - 4, Kirigami.Units.iconSizes.small))
                                                            height: width
                                                            source: root.desktopTaskData(modelData, Qt.DecorationRole)
                                                        }
                                                    }
                                                }

                                                PlasmaComponents3.Label {
                                                    anchors.centerIn: parent
                                                    visible: desktopCard.previewWindowCount === 0
                                                    color: root.mutedTextColor
                                                    text: i18n("Empty")
                                                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.78)
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Kirigami.Units.smallSpacing

                                                PlasmaComponents3.Label {
                                                    Layout.fillWidth: true
                                                    color: root.textColor
                                                    elide: Text.ElideRight
                                                    font.weight: desktopCard.isSelected || desktopCard.isCurrentDesktop ? Font.DemiBold : Font.Normal
                                                    text: root.desktopName(desktopCard.desktopId)
                                                }

                                                PlasmaComponents3.Label {
                                                    color: desktopCard.isCurrentDesktop ? root.accentColor : root.mutedTextColor
                                                    text: desktopCard.previewWindowCount
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: desktopMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: {
                                                if (root.suppressHoverSelectionOnOpen) {
                                                    return;
                                                }

                                                root.selectedDesktopIndex = index;
                                                root.navigationSection = "desktops";
                                            }

                                            onClicked: {
                                                root.selectedDesktopIndex = index;
                                                root.navigationSection = "desktops";
                                                root.triggerSelectedDesktop();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        QQC2.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                            GridView {
                                id: windowsGrid
                                anchors.fill: parent
                                model: windowsModel
                                currentIndex: root.selectedWindowIndex
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true
                                cellWidth: Math.max(300, Math.min(600, width / root.visibleWindowGridColumns()))
                                cellHeight: cellWidth * 0.68
                                readonly property int visibleColumnCount: root.visibleWindowGridColumns()

                                function updateColumns() {
                                    const idealWidth = root.searching ? 300 : 320;
                                    root.windowGridColumns = Math.max(1, Math.floor(Math.max(width, idealWidth) / idealWidth));
                                }

                                onWidthChanged: updateColumns()
                                Component.onCompleted: {
                                    currentIndex = root.selectedWindowIndex;
                                    updateColumns();
                                }

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
                                        onEntered: {
                                            if (root.suppressHoverSelectionOnOpen) {
                                                return;
                                            }

                                            root.selectedWindowIndex = index;
                                            root.navigationSection = "windows";
                                        }
                                        onClicked: mouse => {
                                            root.selectedWindowIndex = index;
                                            root.navigationSection = "windows";

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
}

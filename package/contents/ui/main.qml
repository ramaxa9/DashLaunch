pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

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
    readonly property color selectionBorderColor: Plasmoid.configuration.cursorBorderColor || "#7dcfff"
    readonly property color textColor: "#f5f2eb"
    readonly property color mutedTextColor: Qt.rgba(0.96, 0.94, 0.9, 0.68)
    readonly property int tilePadding: 12
    readonly property string dashboardLayout: Plasmoid.configuration.dashboardLayout || "default"
    readonly property bool appGridLayout: dashboardLayout === "app-grid"

    property string searchText: ""
    property rect currentScreenGeometry: Qt.rect(0, 0, Screen.width, Screen.height)
    property int selectedSearchIndex: 0
    property int selectedWindowIndex: -1
    property int selectedDesktopIndex: -1
    property int windowGridColumns: 1
    property int desktopPreviewRevision: 0
    property bool pendingInitialWindowFocus: false
    property bool suppressHoverSelectionOnOpen: false
    property bool desktopPreviewPinned: false
    property bool keepOpenAfterDrag: false
    property bool dashboardVisible: false
    property string navigationSection: "windows"
    property var fullViewRef: null
    property var windowsGridRef: null
    property var appGridResultsViewRef: null
    property var searchFieldRef: null
    property var desktopCardRefs: []
    property int draggedWindowRow: -1
    property var draggedTaskModelIndex: null
    property string dragTargetDesktopId: ""
    property real dragPointerX: 0
    property real dragPointerY: 0
    property real dragHotspotX: 0
    property real dragHotspotY: 0
    property string draggedWindowTitle: ""
    property string draggedWindowAppName: ""
    property var draggedWindowIcon: null

    readonly property bool dragging: draggedWindowRow >= 0 && draggedTaskModelIndex && draggedTaskModelIndex.valid
    readonly property bool searching: searchText.length > 0
    readonly property bool filterCurrentMonitor: Plasmoid.configuration.showOnlyCurrentMonitor
    readonly property bool filterCurrentVirtualDesktop: Plasmoid.configuration.showOnlyCurrentVirtualDesktop
    readonly property var searchResultsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    readonly property int desktopPreviewWidth: 400
    readonly property int desktopPreviewHeight: currentScreenGeometry.width > 0
        ? Math.round(desktopPreviewWidth * currentScreenGeometry.height / currentScreenGeometry.width)
        : 225
    readonly property string previewDesktopId: !searching && desktopPreviewPinned && selectedDesktopIndex >= 0
        ? desktopIdAt(selectedDesktopIndex)
        : ""
    readonly property bool previewingDesktopWindows: previewDesktopId.length > 0
    readonly property int dashboardWidth: Math.max(640, Math.round(currentScreenGeometry.width * 0.9))
    readonly property int dashboardHeight: Math.max(480, Math.round(currentScreenGeometry.height * 0.9))
    readonly property int dashboardX: currentScreenGeometry.x + Math.round((currentScreenGeometry.width - dashboardWidth) / 2)
    readonly property int dashboardY: currentScreenGeometry.y + Math.round((currentScreenGeometry.height - dashboardHeight) / 2)
    readonly property int windowGridMinCellWidth: Math.max(Kirigami.Units.gridUnit * 12, Math.round(dashboardWidth * 0.20))
    readonly property int windowGridMaxCellWidth: Math.max(windowGridMinCellWidth, Math.round(dashboardWidth * 0.21))
    readonly property int windowGridTargetCellWidth: Math.round((windowGridMinCellWidth + windowGridMaxCellWidth) / 2)
    readonly property bool appGridSearchActive: appGridLayout && searching
    readonly property int appGridSearchFieldWidth: Math.round(dashboardWidth * 0.2)
    readonly property int appGridResultsWidth: dashboardWidth
    readonly property int appGridResultsPadding: Math.round(dashboardWidth * 0.02)
    readonly property int appGridTileSpacing: Kirigami.Units.smallSpacing
    readonly property int appGridIconSize: Math.max(16, Math.round(dashboardWidth * 0.0405))
    readonly property int appGridMinCellWidth: Math.max(Kirigami.Units.gridUnit * 6, Math.round(dashboardWidth * 0.06))
    readonly property int appGridMaxCellWidth: Math.max(appGridMinCellWidth, Math.round(dashboardWidth * 0.07))
    readonly property real appGridCellAspectRatio: 1.0
    readonly property int appGridColumns: Math.max(1, Math.floor(appGridResultsWidth / appGridMinCellWidth))

    Plasmoid.title: "Dash Launch"
    Plasmoid.icon: Plasmoid.configuration.widgetIcon || "view-grid"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: compactRepresentation

    function clearSearch() {
        searchText = "";
        selectedSearchIndex = 0;
    }

    function shouldClearSearchOnEscape() {
        return searching && searchText.length > 0;
    }

    function handleEscape() {
        if (shouldClearSearchOnEscape()) {
            clearSearch();
        } else {
            closeDashboard();
        }
    }

    function focusDashboardView() {
        if (fullViewRef) {
            fullViewRef.forceActiveFocus();
        }
    }

    function focusSearchField() {
        if (searchFieldRef && searchFieldRef.visible) {
            searchFieldRef.forceActiveFocus();
        }
    }

    function resetDragState() {
        draggedWindowRow = -1;
        draggedTaskModelIndex = null;
        dragTargetDesktopId = "";
        dragHotspotX = 0;
        dragHotspotY = 0;
        draggedWindowTitle = "";
        draggedWindowAppName = "";
        draggedWindowIcon = null;
    }

    function holdDashboardOpenAfterDrag() {
        keepOpenAfterDrag = true;
        keepOpenAfterDragTimer.restart();
    }

    function closeDashboard() {
        root.dashboardVisible = false;
        clearSearch();
        selectedWindowIndex = -1;
        selectedDesktopIndex = -1;
        desktopPreviewPinned = false;
        navigationSection = "windows";
        resetDragState();
    }

    function taskIndex(row) {
        const visibleRows = visibleWindowRows();
        if (row < 0 || row >= visibleRows.length) {
            return windowsModel.index(-1, 0);
        }

        return windowsModel.index(visibleRows[row], 0);
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

    function desktopIndex(desktopId) {
        return (virtualDesktopInfo.desktopIds || []).indexOf(desktopId);
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

    function taskAppName(row) {
        return taskData(row, TaskManager.AbstractTasksModel.AppName) || i18n("Application");
    }

    function normalizedTaskString(value) {
        return String(value || "").trim().toLowerCase();
    }

    function isDashboardTask(model, row) {
        const modelIndex = model.index(row, 0);
        if (!modelIndex.valid) {
            return false;
        }

        const displayName = normalizedTaskString(model.data(modelIndex, Qt.DisplayRole));
        const appName = normalizedTaskString(model.data(modelIndex, TaskManager.AbstractTasksModel.AppName));
        const appId = normalizedTaskString(model.data(modelIndex, TaskManager.AbstractTasksModel.AppId));
        const launcherUrl = normalizedTaskString(model.data(modelIndex, TaskManager.AbstractTasksModel.LauncherUrl));
        const dashboardTitle = normalizedTaskString(Plasmoid.title);

        return displayName === dashboardTitle
            || appName === dashboardTitle
            || appId.indexOf("org.kde.plasma.dashlaunch") >= 0
            || appId.indexOf("dashlaunch") >= 0
            || launcherUrl.indexOf("org.kde.plasma.dashlaunch") >= 0
            || launcherUrl.indexOf("dashlaunch") >= 0;
    }

    function isWindowTaskVisible(row) {
        const modelIndex = windowsModel.index(row, 0);
        if (!modelIndex.valid) {
            return false;
        }

        return !Boolean(windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.SkipTaskbar))
            && !isDashboardTask(windowsModel, row);
    }

    function visibleWindowRows() {
        const rows = [];

        for (let row = 0; row < windowsModel.count; ++row) {
            if (isWindowTaskVisible(row)) {
                rows.push(row);
            }
        }

        return rows;
    }

    function visibleWindowCount() {
        return visibleWindowRows().length;
    }

    function expandedWindow() {
        return dashboardWindow.visible ? dashboardWindow : null;
    }

    function updateCurrentScreenGeometry() {
        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            currentScreenGeometry = Qt.rect(0, 0, Screen.width, Screen.height);
            return;
        }

        let resolvedScreen = null;
        const plasmoidScreenIndex = Plasmoid.screen;
        if (plasmoidScreenIndex >= 0 && plasmoidScreenIndex < screens.length) {
            resolvedScreen = screens[plasmoidScreenIndex];
        }

        if (!resolvedScreen) {
            const window = root.expandedWindow();
            if (window && window.screen) {
                resolvedScreen = window.screen;
            }
        }

        if (!resolvedScreen) {
            resolvedScreen = screens[0];
        }

        const sx = resolvedScreen.virtualX !== undefined ? resolvedScreen.virtualX : 0;
        const sy = resolvedScreen.virtualY !== undefined ? resolvedScreen.virtualY : 0;
        currentScreenGeometry = Qt.rect(sx, sy, resolvedScreen.width, resolvedScreen.height);
    }

    function syncDesktopSelection() {
        const desktopIds = virtualDesktopInfo.desktopIds || [];
        if (desktopIds.length === 0) {
            selectedDesktopIndex = -1;
            desktopPreviewPinned = false;
            if (navigationSection === "desktops") {
                navigationSection = "windows";
            }
            return;
        }

        const currentDesktop = virtualDesktopInfo.currentDesktop;
        const currentIndex = desktopIds.indexOf(currentDesktop);

        if (selectedDesktopIndex < 0 || selectedDesktopIndex >= desktopIds.length) {
            selectedDesktopIndex = Math.max(0, currentIndex);
        }
    }

    function syncWindowSelection() {
        const count = visibleWindowCount();
        if (count <= 0) {
            selectedWindowIndex = -1;
            if (navigationSection === "windows") {
                navigationSection = (virtualDesktopInfo.desktopIds || []).length > 0 ? "desktops" : "windows";
            }
            return;
        }

        if (selectedWindowIndex < 0 || selectedWindowIndex >= count) {
            selectedWindowIndex = 0;
        }
    }

    function focusInitialSelection() {
        syncWindowSelection();
        if (selectedWindowIndex >= 0) {
            navigationSection = "windows";
            return;
        }

        syncDesktopSelection();
        navigationSection = selectedDesktopIndex >= 0 ? "desktops" : "windows";
    }

    function applyPendingInitialWindowFocus() {
        if (!pendingInitialWindowFocus || !dashboardVisible) {
            return;
        }

        focusInitialSelection();
        pendingInitialWindowFocus = false;
    }

    function visibleWindowGridColumns() {
        return Math.max(1, Math.min(windowGridColumns, visibleWindowCount() || 1));
    }

    function refreshWindowGridLayout() {
        Qt.callLater(function() {
            const grid = root.windowsGridRef;
            if (!grid) {
                return;
            }

            grid.updateColumns();

            if (grid.currentIndex >= 0) {
                grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
            }
        });
    }

    function refreshDesktopPreviews() {
        desktopPreviewRevision += 1;
    }

    function refreshWindowModels() {
        windowsModel.sort(0);
        windowsModel.invalidate();
        desktopWindowsModel.sort(0);
        desktopWindowsModel.invalidate();
        syncWindowSelection();
        refreshWindowGridLayout();
        refreshDesktopPreviews();
    }

    function selectDesktop(index, pinPreview) {
        selectedDesktopIndex = index;
        navigationSection = "desktops";
        desktopPreviewPinned = pinPreview;
    }

    function moveSearchSelection(step) {
        const count = searchResultsModel ? searchResultsModel.count : 0;
        if (count <= 0) {
            return;
        }

        selectedSearchIndex = Math.max(0, Math.min(count - 1, selectedSearchIndex + step));
    }

    function visibleAppGridColumns() {
        const view = appGridResultsViewRef;
        if (view && view.responsiveColumns > 0) {
            return view.responsiveColumns;
        }

        return appGridColumns;
    }

    function moveAppGridSelectionVertical(step) {
        const count = searchResultsModel ? searchResultsModel.count : 0;
        if (count <= 0) {
            return;
        }

        const columns = visibleAppGridColumns();
        const currentIndex = Math.max(0, Math.min(count - 1, selectedSearchIndex));
        const currentColumn = currentIndex % columns;
        const currentRow = Math.floor(currentIndex / columns);
        const targetRow = Math.max(0, currentRow + step);
        const targetIndex = (targetRow * columns) + currentColumn;

        selectedSearchIndex = Math.max(0, Math.min(count - 1, targetIndex));
    }

    function moveWindowSelectionHorizontal(step) {
        const count = visibleWindowCount();
        if (count <= 0) {
            return;
        }

        syncWindowSelection();
        selectedWindowIndex = Math.max(0, Math.min(count - 1, selectedWindowIndex + step));
    }

    function moveWindowSelectionVertical(step) {
        const count = visibleWindowCount();
        if (count <= 0) {
            return;
        }

        syncWindowSelection();

        const columns = visibleWindowGridColumns();
        const currentColumn = selectedWindowIndex % columns;
        const currentRow = Math.floor(selectedWindowIndex / columns);
        const targetRow = Math.max(0, currentRow + step);
        const targetIndex = (targetRow * columns) + currentColumn;
        selectedWindowIndex = Math.max(0, Math.min(count - 1, targetIndex));
    }

    function moveDesktopSelection(step) {
        const desktopIds = virtualDesktopInfo.desktopIds || [];
        if (desktopIds.length <= 0) {
            return;
        }

        syncDesktopSelection();
        navigationSection = "desktops";
        desktopPreviewPinned = true;
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

        const count = visibleWindowCount();
        if (count <= 1) {
            selectedWindowIndex = -1;
            return;
        }

        selectedWindowIndex = Math.max(0, Math.min(count - 2, row));
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
                if (appGridSearchActive) {
                    moveAppGridSelectionVertical(-1);
                } else {
                    moveSearchSelection(-1);
                }
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
                if (appGridSearchActive) {
                    moveAppGridSelectionVertical(1);
                } else {
                    moveSearchSelection(1);
                }
            } else if (navigationSection === "desktops") {
                focusWindowSelection();
            } else {
                moveWindowSelectionVertical(1);
            }
            event.accepted = true;
            return true;
        }

        if (searching && appGridSearchActive && event.key === Qt.Key_Left) {
            moveSearchSelection(-1);
            event.accepted = true;
            return true;
        }

        if (searching && appGridSearchActive && event.key === Qt.Key_Right) {
            moveSearchSelection(1);
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
        if (desktopTaskData(row, TaskManager.AbstractTasksModel.SkipTaskbar) || isDashboardTask(desktopWindowsModel, row)) {
            return false;
        }

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

    function registerDesktopCard(index, item) {
        const cards = (root.desktopCardRefs || []).slice();
        cards[index] = item;
        root.desktopCardRefs = cards;
    }

    function unregisterDesktopCard(index, item) {
        const cards = (root.desktopCardRefs || []).slice();
        if (cards[index] === item) {
            cards[index] = null;
            root.desktopCardRefs = cards;
        }
    }

    function desktopCardAtPosition(x, y) {
        const view = root.fullViewRef;
        const cards = root.desktopCardRefs || [];
        if (!view || cards.length === 0) {
            return null;
        }

        for (let index = 0; index < cards.length; ++index) {
            const item = cards[index];
            if (!item || !item.visible) {
                continue;
            }

            const topLeft = item.mapToItem(view, 0, 0);
            if (x >= topLeft.x && x <= topLeft.x + item.width && y >= topLeft.y && y <= topLeft.y + item.height) {
                return item;
            }
        }

        return null;
    }

    function updateDragTarget(x, y) {
        const desktopCard = desktopCardAtPosition(x, y);
        dragTargetDesktopId = desktopCard ? desktopCard.desktopId : "";
    }

    function startWindowDrag(row, sourceItem, pointerX, pointerY) {
        const view = root.fullViewRef;
        const index = taskIndex(row);
        if (!view || !index.valid) {
            return;
        }

        const localPoint = sourceItem.mapToItem(view, pointerX, pointerY);
        const itemOrigin = sourceItem.mapToItem(view, 0, 0);

        draggedWindowRow = row;
        draggedTaskModelIndex = index;
        draggedWindowTitle = taskData(row, Qt.DisplayRole) || taskAppName(row);
        draggedWindowAppName = taskAppName(row);
        draggedWindowIcon = taskData(row, Qt.DecorationRole);
        dragPointerX = localPoint.x;
        dragPointerY = localPoint.y;
        dragHotspotX = sourceItem.width / 2;
        dragHotspotY = sourceItem.height / 2;
        updateDragTarget(dragPointerX, dragPointerY);
    }

    function continueWindowDrag(sourceItem, pointerX, pointerY) {
        if (!dragging) {
            return;
        }

        const view = root.fullViewRef;
        if (!view) {
            return;
        }

        const localPoint = sourceItem.mapToItem(view, pointerX, pointerY);
        dragPointerX = localPoint.x;
        dragPointerY = localPoint.y;
        updateDragTarget(dragPointerX, dragPointerY);
    }

    function moveWindowToDesktop(modelIndex, desktopId) {
        if (!modelIndex || !modelIndex.valid || !desktopId) {
            return false;
        }

        const existingDesktopIds = windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.VirtualDesktops) || [];
        if (!windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops)
            && existingDesktopIds.length === 1 && existingDesktopIds[0] === desktopId) {
            return false;
        }

        windowsModel.requestVirtualDesktops(modelIndex, [desktopId]);
        return true;
    }

    function finishWindowDrag() {
        if (!dragging) {
            resetDragState();
            return false;
        }

        const moved = dragTargetDesktopId ? moveWindowToDesktop(draggedTaskModelIndex, dragTargetDesktopId) : false;
        if (moved) {
            holdDashboardOpenAfterDrag();
        }
        resetDragState();
        return moved;
    }

    onDashboardVisibleChanged: {
        if (!root.dashboardVisible) {
            pendingInitialWindowFocus = false;
            suppressHoverSelectionOnOpen = false;
            desktopPreviewPinned = false;
            navigationSection = "windows";
            clearSearch();
            resetDragState();
            return;
        }

        pendingInitialWindowFocus = true;
        suppressHoverSelectionOnOpen = true;
        updateCurrentScreenGeometry();
        refreshWindowModels();
        syncDesktopSelection();
        focusInitialSelection();
        Qt.callLater(updateCurrentScreenGeometry);
        Qt.callLater(refreshDesktopPreviews);
        Qt.callLater(focusDashboardView);
        Qt.callLater(applyPendingInitialWindowFocus);
    }

    onExpandedChanged: {
        if (root.expanded) {
            root.expanded = false;
            if (root.dashboardVisible) {
                root.closeDashboard();
            } else {
                root.dashboardVisible = true;
            }
        }
    }

    onKeepOpenAfterDragChanged: {
        if (!root.keepOpenAfterDrag && root.dashboardVisible && dashboardWindow.visible && !dashboardWindow.active) {
            root.closeDashboard();
        }
    }

    onSearchingChanged: {
        refreshWindowGridLayout();

        if (root.appGridSearchActive) {
            Qt.callLater(focusSearchField);
        } else if (!root.searching) {
            Qt.callLater(focusDashboardView);
        }
    }

    onPreviewDesktopIdChanged: {
        windowsModel.invalidate();
        syncWindowSelection();
        refreshWindowGridLayout();
    }

    onFilterCurrentMonitorChanged: {
        updateCurrentScreenGeometry();
        refreshWindowModels();
    }

    onFilterCurrentVirtualDesktopChanged: refreshWindowModels()

    onSelectedWindowIndexChanged: {
        const grid = root.windowsGridRef;
        if (!grid) {
            return;
        }

        if (grid.currentIndex !== selectedWindowIndex) {
            grid.currentIndex = selectedWindowIndex;
        }
    }

    onSearchTextChanged: {
        selectedSearchIndex = 0;
        if (!searching && fullViewRef && searchFieldRef && searchFieldRef.activeFocus) {
            fullViewRef.forceActiveFocus();
        }
    }

    Component.onCompleted: updateCurrentScreenGeometry()

    Connections {
        target: virtualDesktopInfo

        function onCurrentDesktopChanged() {
            if (root.filterCurrentVirtualDesktop && !root.previewingDesktopWindows) {
                windowsModel.invalidate();
                root.syncWindowSelection();
                root.refreshWindowGridLayout();
            }

            root.syncDesktopSelection();
            root.refreshDesktopPreviews();
        }

        function onDesktopIdsChanged() {
            root.syncDesktopSelection();
            root.refreshDesktopPreviews();
        }
    }

    Connections {
        target: Plasmoid

        function onScreenChanged() {
            root.updateCurrentScreenGeometry();
            root.refreshWindowModels();
        }

        function onScreenGeometryChanged() {
            root.updateCurrentScreenGeometry();
            root.refreshWindowModels();
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

    Timer {
        id: keepOpenAfterDragTimer
        interval: 350
        repeat: false
        onTriggered: root.keepOpenAfterDrag = false
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: windowsModel
        activity: ""
        virtualDesktop: root.previewingDesktopWindows ? root.previewDesktopId : virtualDesktopInfo.currentDesktop
        filterByVirtualDesktop: root.filterCurrentVirtualDesktop || root.previewingDesktopWindows
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
        filterByScreen: root.filterCurrentMonitor
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
            color: root.dashboardVisible ? root.surfaceHoverColor : root.surfaceColor
            border.color: root.dashboardVisible ? root.selectionBorderColor : root.borderColor

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
            onClicked: root.dashboardVisible = !root.dashboardVisible
        }
    }

    Component {
        id: dashboardContentComponent

    FocusScope {
        id: fullView
        anchors.fill: parent
        focus: root.dashboardVisible

        Component.onCompleted: {
            root.fullViewRef = fullView;
            Qt.callLater(root.focusDashboardView);
        }

        Component.onDestruction: {
            if (root.fullViewRef === fullView) {
                root.fullViewRef = null;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius * 1.4
            color: root.panelColor
            border.color: root.borderColor
        }

        Rectangle {
            z: 20
            visible: root.dragging
            x: root.dragPointerX - root.dragHotspotX
            y: root.dragPointerY - root.dragHotspotY
            width: Math.max(
                Kirigami.Units.gridUnit * 12,
                root.windowsGridRef ? Math.min(root.windowsGridRef.cellWidth - root.tilePadding, Kirigami.Units.gridUnit * 18) : Kirigami.Units.gridUnit * 14
            )
            height: width * 0.68
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(0.12, 0.15, 0.2, 0.94)
            border.width: 1.5
            border.color: root.selectionBorderColor
            opacity: 0.96

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.tilePadding
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: width
                        source: root.draggedWindowIcon
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        color: root.textColor
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        text: root.draggedWindowTitle
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.05)
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.parent.height * 0.6
                            height: width
                            source: root.draggedWindowIcon
                        }

                        PlasmaComponents3.Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            color: root.mutedTextColor
                            elide: Text.ElideRight
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.95)
                            text: root.draggedWindowAppName
                        }
                    }
                }
            }
        }

        Keys.onEscapePressed: event => {
            root.handleEscape();
            event.accepted = true;
        }

        Keys.onPressed: event => {
            if (root.handleNavigationKey(event)) {
                return;
            }

            if (root.searchFieldRef && root.searchFieldRef.activeFocus) {
                return;
            }

            if ((event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0) {
                return;
            }

            if (event.text && event.text.length > 0) {
                root.searchText += event.text;
                Qt.callLater(root.focusSearchField);
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
                visible: !root.appGridSearchActive
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    visible: root.searching && !root.appGridSearchActive
                    Layout.preferredWidth: root.searching ? Math.round(parent.width * 0.2) : 0
                    Layout.maximumWidth: root.searching ? Math.round(parent.width * 0.2) : 0
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

                            Component.onCompleted: {
                                if (searchField.visible) {
                                    root.searchFieldRef = searchField;
                                }
                            }

                            Component.onDestruction: {
                                if (root.searchFieldRef === searchField) {
                                    root.searchFieldRef = null;
                                }
                            }

                            onVisibleChanged: {
                                if (visible) {
                                    root.searchFieldRef = searchField;
                                } else if (root.searchFieldRef === searchField) {
                                    root.searchFieldRef = null;
                                }
                            }

                            background: Rectangle {
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.color: searchField.activeFocus ? root.selectionBorderColor : root.borderColor
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
                                root.handleEscape();
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
                    visible: !root.appGridSearchActive
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
                                        readonly property bool isPreviewing: root.previewDesktopId === desktopId
                                        readonly property bool isSelected: !root.searching && root.navigationSection === "desktops" && root.selectedDesktopIndex === index
                                        readonly property bool isDragTarget: root.dragging && root.dragTargetDesktopId === desktopId
                                        readonly property int previewWindowCount: {
                                            root.desktopPreviewRevision;
                                            return root.desktopWindowCount(desktopId);
                                        }

                                        width: root.desktopPreviewWidth
                                        height: root.desktopPreviewHeight + (Kirigami.Units.gridUnit * 1.8)
                                        radius: Kirigami.Units.cornerRadius

                                        Component.onCompleted: root.registerDesktopCard(index, desktopCard)
                                        Component.onDestruction: root.unregisterDesktopCard(index, desktopCard)

                                        color: desktopMouseArea.containsMouse || isDragTarget || isSelected || isPreviewing || isCurrentDesktop
                                            ? Qt.rgba(1, 1, 1, 0.08)
                                            : "transparent"
                                        border.width: isDragTarget || isSelected || isPreviewing ? 1.8 : (isCurrentDesktop ? 1.5 : 1)
                                        border.color: isDragTarget || isSelected || isPreviewing || isCurrentDesktop
                                            ? root.selectionBorderColor
                                            : root.borderColor

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
                                                    model: root.dashboardVisible
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
                                                    color: desktopCard.isCurrentDesktop || desktopCard.isPreviewing || desktopCard.isDragTarget
                                                        ? root.selectionBorderColor
                                                        : root.mutedTextColor
                                                    text: desktopCard.previewWindowCount
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: desktopMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: root.selectDesktop(index, true)

                                            onDoubleClicked: {
                                                root.selectDesktop(index, true);
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
                                model: root.visibleWindowRows()
                                currentIndex: root.selectedWindowIndex
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true
                                cellWidth: Math.max(root.windowGridMinCellWidth, Math.min(root.windowGridMaxCellWidth, width / root.visibleWindowGridColumns()))
                                cellHeight: cellWidth * 0.68

                                function updateColumns() {
                                    const idealWidth = root.windowGridTargetCellWidth;
                                    root.windowGridColumns = Math.max(1, Math.floor(Math.max(width, idealWidth) / idealWidth));
                                }

                                onWidthChanged: updateColumns()

                                Component.onCompleted: {
                                    root.windowsGridRef = windowsGrid;
                                    currentIndex = root.selectedWindowIndex;
                                    updateColumns();
                                }

                                Component.onDestruction: {
                                    if (root.windowsGridRef === windowsGrid) {
                                        root.windowsGridRef = null;
                                    }
                                }

                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0) {
                                        positionViewAtIndex(currentIndex, GridView.Contain);
                                    }
                                }

                                delegate: Rectangle {
                                    id: windowCard
                                    required property int index
                                    required property int modelData
                                    property bool dragConsumed: false

                                    width: windowsGrid.cellWidth - root.tilePadding
                                    height: windowsGrid.cellHeight - root.tilePadding
                                    radius: Kirigami.Units.cornerRadius
                                    z: root.draggedWindowRow === index ? 2 : 0
                                    opacity: root.draggedWindowRow === index ? 0.25 : 1
                                    color: (!root.dragging && (windowHoverHandler.hovered || root.selectedWindowIndex === index)) || root.draggedWindowRow === index
                                        ? root.surfaceHoverColor
                                        : "transparent"
                                    border.width: !root.dragging && root.selectedWindowIndex === index ? 1.5 : 1
                                    border.color: (!root.dragging && root.selectedWindowIndex === index) || root.draggedWindowRow === index
                                        ? root.selectionBorderColor
                                        : root.borderColor

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

                                    HoverHandler {
                                        id: windowHoverHandler

                                        onHoveredChanged: {
                                            if (!hovered || root.suppressHoverSelectionOnOpen || root.dragging) {
                                                return;
                                            }

                                            root.selectedWindowIndex = index;
                                            root.navigationSection = "windows";
                                        }
                                    }

                                    TapHandler {
                                        acceptedButtons: Qt.LeftButton
                                        gesturePolicy: TapHandler.DragThreshold
                                        enabled: !root.dragging

                                        onTapped: {
                                            if (windowCard.dragConsumed) {
                                                windowCard.dragConsumed = false;
                                                return;
                                            }

                                            root.selectedWindowIndex = index;
                                            root.navigationSection = "windows";
                                            root.activateWindow(index);
                                        }
                                    }

                                    TapHandler {
                                        acceptedButtons: Qt.MiddleButton
                                        gesturePolicy: TapHandler.DragThreshold
                                        enabled: !root.dragging

                                        onTapped: {
                                            if (windowCard.dragConsumed) {
                                                windowCard.dragConsumed = false;
                                                return;
                                            }

                                            root.selectedWindowIndex = index;
                                            root.navigationSection = "windows";
                                            root.closeWindow(index);
                                        }
                                    }

                                    DragHandler {
                                        id: windowDragHandler
                                        target: null
                                        acceptedButtons: Qt.LeftButton
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                                        cursorShape: Qt.ClosedHandCursor

                                        onActiveChanged: {
                                            if (active) {
                                                windowCard.dragConsumed = false;
                                                root.selectedWindowIndex = index;
                                                root.navigationSection = "windows";
                                                root.startWindowDrag(index, windowCard, centroid.position.x, centroid.position.y);
                                                return;
                                            }

                                            if (root.draggedWindowRow === index) {
                                                root.continueWindowDrag(windowCard, centroid.position.x, centroid.position.y);
                                                root.finishWindowDrag();
                                            }
                                        }

                                        onTranslationChanged: {
                                            if (!active || root.draggedWindowRow !== index) {
                                                return;
                                            }

                                            windowCard.dragConsumed = true;
                                            root.continueWindowDrag(windowCard, centroid.position.x, centroid.position.y);
                                        }
                                    }
                                }

                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    color: root.mutedTextColor
                                    text: root.previewingDesktopWindows
                                        ? i18n("No open windows on this desktop")
                                        : (root.filterCurrentMonitor ? i18n("No open windows on current monitor") : i18n("No open windows"))
                                    visible: root.visibleWindowCount() === 0
                                }
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.appGridSearchActive
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.largeSpacing

                    QQC2.TextField {
                        id: appGridSearchField
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: root.appGridSearchFieldWidth
                        Layout.maximumWidth: root.appGridSearchFieldWidth
                        text: root.searchText
                        color: root.textColor
                        placeholderText: i18n("Search applications")
                        selectByMouse: true

                        onTextEdited: root.searchText = text

                        Component.onCompleted: {
                            if (appGridSearchField.visible) {
                                root.searchFieldRef = appGridSearchField;
                            }
                        }

                        Component.onDestruction: {
                            if (root.searchFieldRef === appGridSearchField) {
                                root.searchFieldRef = null;
                            }
                        }

                        onVisibleChanged: {
                            if (visible) {
                                root.searchFieldRef = appGridSearchField;
                            } else if (root.searchFieldRef === appGridSearchField) {
                                root.searchFieldRef = null;
                            }
                        }

                        background: Rectangle {
                            radius: Kirigami.Units.cornerRadius
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: appGridSearchField.activeFocus ? root.selectionBorderColor : root.borderColor
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
                            root.handleEscape();
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Kirigami.Units.cornerRadius
                        color: root.surfaceColor
                        border.color: root.borderColor

                        GridView {
                            id: appGridResultsView
                            anchors.fill: parent
                            anchors.margins: root.appGridResultsPadding
                            clip: true
                            property int responsiveColumns: {
                                const count = root.searchResultsModel ? root.searchResultsModel.count : 0;
                                const maxColumns = Math.max(1, Math.floor(width / root.appGridMinCellWidth));
                                return Math.max(1, Math.min(count > 0 ? count : 1, maxColumns));
                            }
                            cellWidth: Math.max(root.appGridMinCellWidth, Math.min(root.appGridMaxCellWidth, Math.floor(width / responsiveColumns)))
                            cellHeight: Math.max(Kirigami.Units.gridUnit * 8, Math.round(cellWidth * root.appGridCellAspectRatio))
                            model: root.searchResultsModel
                            currentIndex: root.selectedSearchIndex
                            boundsBehavior: Flickable.StopAtBounds

                            Component.onCompleted: root.appGridResultsViewRef = appGridResultsView

                            Component.onDestruction: {
                                if (root.appGridResultsViewRef === appGridResultsView) {
                                    root.appGridResultsViewRef = null;
                                }
                            }

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    positionViewAtIndex(currentIndex, GridView.Contain);
                                }
                            }

                            delegate: Rectangle {
                                required property int index
                                required property var model

                                width: Math.max(1, appGridResultsView.cellWidth - root.appGridTileSpacing)
                                height: Math.max(1, appGridResultsView.cellHeight - root.appGridTileSpacing)
                                radius: Kirigami.Units.cornerRadius
                                color: appGridResultMouseArea.containsMouse || root.selectedSearchIndex === index
                                    ? root.surfaceHoverColor
                                    : "transparent"
                                border.width: root.selectedSearchIndex === index ? 1.5 : 1
                                border.color: root.selectedSearchIndex === index ? root.selectionBorderColor : root.borderColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.largeSpacing
                                    spacing: 5

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: root.appGridIconSize
                                            height: root.appGridIconSize
                                            source: model.decoration
                                        }
                                    }

                                    PlasmaComponents3.Label {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        color: root.textColor
                                        elide: Text.ElideRight
                                        text: model.display
                                    }
                                }

                                MouseArea {
                                    id: appGridResultMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    QQC2.ToolTip.visible: containsMouse && ((model.description || "").length > 0)
                                    QQC2.ToolTip.delay: 300
                                    QQC2.ToolTip.text: model.description || ""

                                    onClicked: {
                                        root.selectedSearchIndex = index;
                                        root.triggerSelectedSearchResult();
                                    }
                                }
                            }
                        }

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            color: root.mutedTextColor
                            text: i18n("Nothing found")
                            visible: !root.searchResultsModel || root.searchResultsModel.count === 0
                        }
                    }
                }
            }
        }
    }

    }

    Window {
        id: dashboardWindow
        visible: root.dashboardVisible
        flags: Qt.Dialog | Qt.Tool | Qt.FramelessWindowHint
        color: "transparent"
        title: Plasmoid.title
        x: root.dashboardX
        y: root.dashboardY
        width: root.dashboardWidth
        height: root.dashboardHeight

        onActiveChanged: {
            if (!active && visible && !(root.dragging || root.keepOpenAfterDrag)) {
                root.closeDashboard();
            }
        }

        onVisibleChanged: {
            if (!visible && root.dashboardVisible) {
                root.dashboardVisible = false;
                return;
            }

            if (visible) {
                requestActivate();
                Qt.callLater(root.focusDashboardView);
            }
        }

        Shortcut {
            context: Qt.WindowShortcut
            enabled: dashboardWindow.visible
            sequence: "Escape"
            onActivated: root.handleEscape()
        }

        Loader {
            anchors.fill: parent
            active: dashboardWindow.visible
            sourceComponent: dashboardContentComponent
        }
    }

    fullRepresentation: Item {
        implicitWidth: 0
        implicitHeight: 0
    }
}
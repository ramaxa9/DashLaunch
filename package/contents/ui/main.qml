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

import "components" as Components

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
    property int appGridTooltipIndex: -1
    property int selectedWindowIndex: -1
    property int selectedDesktopIndex: -1
    property int selectedScreenIndex: -1
    property int windowGridColumns: 1
    property int desktopPreviewRevision: 0
    property bool pendingInitialWindowFocus: false
    property bool suppressHoverSelectionOnOpen: false
    property bool suppressAutoCloseOnDragDrop: false
    property bool desktopPreviewPinned: false
    property bool screenPreviewPinned: false
    property bool keepOpenAfterDrag: false
    property bool dashboardVisible: false
    property bool dashboardWindowVisible: false
    property bool dashboardContentVisible: false
    property string navigationSection: "windows"
    property var fullViewRef: null
    property var windowsGridRef: null
    property var appGridResultsViewRef: null
    property var searchFieldRef: null
    property var screenCardRefs: []
    property var desktopCardRefs: []
    property int draggedWindowRow: -1
    property var draggedTaskModelIndex: null
    property string dragTargetDesktopId: ""
    property string dragTargetScreenName: ""
    property real dragPointerX: 0
    property real dragPointerY: 0
    property real dragHotspotX: 0
    property real dragHotspotY: 0
    property string draggedWindowTitle: ""
    property string draggedWindowAppName: ""
    property var draggedWindowIcon: null
    property bool fullscreenMode: Plasmoid.configuration.enableFullscreen || false
    property string monitorSelectionMode: Plasmoid.configuration.monitorSelectionMode || "widget"
    property string targetMonitorName: Plasmoid.configuration.targetMonitorName || ""
    property string followMouseMonitorName: ""
    property bool pendingFollowMouseOpen: false
    readonly property int dashboardFadeDuration: 140

    readonly property bool dragging: draggedWindowRow >= 0 && draggedTaskModelIndex && draggedTaskModelIndex.valid
    readonly property bool searching: searchText.length > 0
    readonly property bool filterCurrentMonitor: Plasmoid.configuration.showOnlyCurrentMonitor
    readonly property bool filterCurrentVirtualDesktop: Plasmoid.configuration.showOnlyCurrentVirtualDesktop
    readonly property var searchResultsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    readonly property int desktopPreviewWidth: 400
    readonly property int desktopPreviewHeight: currentScreenGeometry.width > 0
        ? Math.round(desktopPreviewWidth * currentScreenGeometry.height / currentScreenGeometry.width)
        : 225
    readonly property int screenPreviewWidth: Math.max(Kirigami.Units.gridUnit * 8, Math.round(desktopPreviewWidth * 0.34))
    readonly property string previewDesktopId: !searching && desktopPreviewPinned && selectedDesktopIndex >= 0
        ? desktopIdAt(selectedDesktopIndex)
        : ""
    readonly property string previewScreenName: !searching && screenPreviewPinned && selectedScreenIndex >= 0
        ? screenNameAt(selectedScreenIndex)
        : ""
    readonly property bool previewingDesktopWindows: previewDesktopId.length > 0
    readonly property bool previewingScreenWindows: previewScreenName.length > 0
    readonly property rect activePreviewScreenGeometry: previewingScreenWindows
        ? screenGeometryAt(selectedScreenIndex)
        : currentScreenGeometry
    readonly property int dashboardWidth: Math.max(640, Math.round(currentScreenGeometry.width * 0.95))
    readonly property int dashboardHeight: Math.max(480, Math.round(currentScreenGeometry.height * 0.95))
    readonly property int dashboardX: currentScreenGeometry.x + Math.round((currentScreenGeometry.width - dashboardWidth) / 2)
    readonly property int dashboardY: currentScreenGeometry.y + Math.round((currentScreenGeometry.height - dashboardHeight) / 2)
    readonly property int windowGridMinCellWidth: Math.max(Kirigami.Units.gridUnit * 12, Math.round(dashboardWidth * 0.15))
    readonly property int windowGridMaxCellWidth: Math.max(windowGridMinCellWidth, Math.round(dashboardWidth * 0.20))
    readonly property int windowGridTargetCellWidth: Math.round((windowGridMinCellWidth + windowGridMaxCellWidth) / 2)
    readonly property bool appGridSearchActive: appGridLayout && searching
    readonly property int appGridSearchFieldWidth: Math.round(dashboardWidth * 0.2)
    readonly property int appGridResultsWidth: dashboardWidth
    readonly property int appGridResultsPadding: Math.round(dashboardWidth * 0.02)
    readonly property int appGridTileSpacing: Kirigami.Units.smallSpacing
    readonly property int appGridTileSize: Math.max(24, Math.round(Math.min(dashboardWidth, dashboardHeight) * 0.15))
    readonly property int appGridIconSize: Math.round(appGridTileSize * 0.75)
    readonly property int appGridMinCellWidth: appGridTileSize
    readonly property int appGridMaxCellWidth: appGridTileSize
    readonly property real appGridCellAspectRatio: 1.0
    readonly property int appGridColumns: Math.max(1, Math.floor(appGridResultsWidth / appGridMinCellWidth))
    readonly property int windowTileMinWidth: Math.round(dashboardWidth * 0.15)
    readonly property int windowTileMaxWidth: Math.max(windowTileMinWidth, Math.round(dashboardWidth * 0.20))

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
        dragTargetScreenName = "";
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
        if (!root.dashboardVisible && !root.dashboardWindowVisible) {
            return;
        }

        root.dashboardVisible = false;
        root.dashboardContentVisible = false;
        clearSearch();
        selectedWindowIndex = -1;
        selectedDesktopIndex = -1;
        desktopPreviewPinned = false;
        navigationSection = "windows";
        resetDragState();

        if (!dashboardWindowVisible) {
            return;
        }

        dashboardHideTimer.restart();
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

    function screenCount() {
        const screens = Qt.application.screens;
        return screens ? screens.length : 0;
    }

    function screenAt(index) {
        const screens = Qt.application.screens;
        if (!screens || index < 0 || index >= screens.length) {
            return null;
        }

        return screens[index];
    }

    function screenNameAt(index) {
        const screen = screenAt(index);
        return screen ? String(screen.name || "") : "";
    }

    function screenLabelAt(index) {
        const screen = screenAt(index);
        if (!screen) {
            return i18n("Monitor");
        }

        return String(screen.name || "").trim() || i18n("Monitor %1", index + 1);
    }

    function screenGeometryAt(index) {
        const screen = screenAt(index);
        if (!screen) {
            return currentScreenGeometry;
        }

        const sx = screen.virtualX !== undefined ? screen.virtualX : 0;
        const sy = screen.virtualY !== undefined ? screen.virtualY : 0;
        return Qt.rect(sx, sy, screen.width, screen.height);
    }

    function screenLayoutBounds() {
        const count = screenCount();
        if (count <= 0) {
            return Qt.rect(0, 0, Math.max(1, currentScreenGeometry.width), Math.max(1, currentScreenGeometry.height));
        }

        let minX = 0;
        let minY = 0;
        let maxX = 0;
        let maxY = 0;

        for (let index = 0; index < count; ++index) {
            const geometry = screenGeometryAt(index);
            if (index === 0) {
                minX = geometry.x;
                minY = geometry.y;
                maxX = geometry.x + geometry.width;
                maxY = geometry.y + geometry.height;
                continue;
            }

            minX = Math.min(minX, geometry.x);
            minY = Math.min(minY, geometry.y);
            maxX = Math.max(maxX, geometry.x + geometry.width);
            maxY = Math.max(maxY, geometry.y + geometry.height);
        }

        return Qt.rect(minX, minY, Math.max(1, maxX - minX), Math.max(1, maxY - minY));
    }

    function screenTileRectAt(index, availableWidth, availableHeight, labelHeight, padding) {
        const bounds = screenLayoutBounds();
        const geometry = screenGeometryAt(index);
        const usableWidth = Math.max(1, availableWidth - (padding * 2));
        const usableHeight = Math.max(1, availableHeight - labelHeight - (padding * 2));
        const scale = Math.min(usableWidth / bounds.width, usableHeight / bounds.height);
        const scaledLayoutWidth = Math.round(bounds.width * scale);
        const scaledLayoutHeight = Math.round(bounds.height * scale);
        const offsetX = Math.round((availableWidth - scaledLayoutWidth) / 2);
        const offsetY = Math.round((availableHeight - labelHeight - scaledLayoutHeight) / 2);

        return Qt.rect(
            offsetX + Math.round((geometry.x - bounds.x) * scale),
            offsetY + Math.round((geometry.y - bounds.y) * scale),
            Math.max(1, Math.round(geometry.width * scale)),
            Math.max(1, Math.round(geometry.height * scale))
        );
    }

    function shellQuote(value) {
        return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\"'\"'") + "'";
    }

    function sameRect(first, second) {
        if (!first || !second) {
            return false;
        }

        return Math.round(first.x) === Math.round(second.x)
            && Math.round(first.y) === Math.round(second.y)
            && Math.round(first.width) === Math.round(second.width)
            && Math.round(first.height) === Math.round(second.height);
    }

    function screenIndexByName(screenName) {
        const screens = Qt.application.screens;
        if (!screens || !screenName) {
            return -1;
        }

        for (let index = 0; index < screens.length; ++index) {
            if (String(screens[index].name || "") === screenName) {
                return index;
            }
        }

        return -1;
    }

    function currentDashboardScreenIndex() {
        const currentScreen = currentScreenObject();
        if (!currentScreen) {
            return -1;
        }

        const currentName = String(currentScreen.name || "");
        if (currentName.length > 0) {
            return screenIndexByName(currentName);
        }

        const screens = Qt.application.screens || [];
        return screens.indexOf(currentScreen);
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

    function primaryScreenObject() {
        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            return null;
        }

        return screens[0];
    }

    function screenForName(screenName) {
        if (!screenName) {
            return null;
        }

        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            return null;
        }

        for (let index = 0; index < screens.length; ++index) {
            const screen = screens[index];
            if (screen && screen.name === screenName) {
                return screen;
            }
        }

        return null;
    }

    function plasmoidScreenObject() {
        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            return null;
        }

        if (Plasmoid.screen && Plasmoid.screen.width !== undefined) {
            return Plasmoid.screen;
        }

        if (typeof Plasmoid.screen === "number" && Plasmoid.screen >= 0 && Plasmoid.screen < screens.length) {
            return screens[Plasmoid.screen];
        }

        return null;
    }

    function currentScreenObject() {
        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            return null;
        }

        const specificScreen = monitorSelectionMode === "specific" ? screenForName(targetMonitorName) : null;
        if (specificScreen) {
            return specificScreen;
        }

        const followMouseScreen = monitorSelectionMode === "follow-mouse" ? screenForName(followMouseMonitorName) : null;
        if (followMouseScreen) {
            return followMouseScreen;
        }

        const plasmoidScreen = plasmoidScreenObject();
        if (plasmoidScreen) {
            return plasmoidScreen;
        }

        if (dashboardWindow.screen) {
            return dashboardWindow.screen;
        }

        return primaryScreenObject();
    }

    function updateCurrentScreenGeometry() {
        const screens = Qt.application.screens;
        if (!screens || screens.length === 0) {
            currentScreenGeometry = Qt.rect(0, 0, Screen.width, Screen.height);
            return;
        }

        const resolvedScreen = currentScreenObject() || screens[0];

        const sx = resolvedScreen.virtualX !== undefined ? resolvedScreen.virtualX : 0;
        const sy = resolvedScreen.virtualY !== undefined ? resolvedScreen.virtualY : 0;
        currentScreenGeometry = Qt.rect(sx, sy, resolvedScreen.width, resolvedScreen.height);
    }

    function applyDashboardWindowPlacement() {
        updateCurrentScreenGeometry();

        const resolvedScreen = currentScreenObject();
        if (resolvedScreen) {
            dashboardWindow.screen = resolvedScreen;
        }

        if (fullscreenMode) {
            dashboardWindow.x = currentScreenGeometry.x;
            dashboardWindow.y = currentScreenGeometry.y;
            dashboardWindow.width = currentScreenGeometry.width;
            dashboardWindow.height = currentScreenGeometry.height;
        } else {
            dashboardWindow.x = dashboardX;
            dashboardWindow.y = dashboardY;
            dashboardWindow.width = dashboardWidth;
            dashboardWindow.height = dashboardHeight;
        }

        if (!dashboardWindow.visible) {
            return;
        }

        applyDashboardWindowMode();
    }

    function applyDashboardWindowMode() {
        if (!dashboardWindow.visible) {
            return;
        }

        if (fullscreenMode) {
            Qt.callLater(() => dashboardWindow.showFullScreen());
        }
    }

    function requestFollowMouseMonitor() {
        pendingFollowMouseOpen = true;
        const command = "qdbus6 org.kde.KWin /KWin org.kde.KWin.activeOutputName";
        activeOutputQuery.disconnectSource(command);
        activeOutputQuery.connectSource(command);
    }

    function finishOpenDashboard() {
        dashboardHideTimer.stop();
        dashboardContentVisible = false;
        applyDashboardWindowPlacement();
        dashboardVisible = true;
        dashboardWindowVisible = true;
    }

    function startDashboardContentFadeIn() {
        Qt.callLater(function() {
            if (!root.dashboardVisible || !root.dashboardWindowVisible) {
                return;
            }

            root.dashboardContentVisible = true;
        });
    }

    function handleFollowMouseMonitorResult(outputName) {
        pendingFollowMouseOpen = false;
        followMouseMonitorName = String(outputName || "").trim();
        finishOpenDashboard();
    }

    function openDashboard() {
        if (monitorSelectionMode === "follow-mouse") {
            requestFollowMouseMonitor();
            return;
        }

        finishOpenDashboard();
    }

    function toggleDashboard() {
        selectedScreenIndex = -1;
        if (dashboardVisible) {
        screenPreviewPinned = false;
            closeDashboard();
        } else {
            openDashboard();
        }
    }

    function syncDesktopSelection(forceCurrent) {
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

        if (forceCurrent || selectedDesktopIndex < 0 || selectedDesktopIndex >= desktopIds.length) {
            selectedDesktopIndex = Math.max(0, currentIndex);
        }
    }

    function syncScreenSelection(forceCurrent) {
        const count = screenCount();
        if (count <= 0) {
            selectedScreenIndex = -1;
            screenPreviewPinned = false;
            return;
        }

        if (forceCurrent || selectedScreenIndex < 0 || selectedScreenIndex >= count) {
            selectedScreenIndex = Math.max(0, currentDashboardScreenIndex());
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

        syncScreenSelection();
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

    function refreshSelectedAppTooltip() {
        if (!appGridSearchActive || !searching) {
            appGridTooltipIndex = -1;
            return;
        }

        const count = searchResultsModel ? searchResultsModel.count : 0;
        const targetIndex = Math.max(0, Math.min(count - 1, selectedSearchIndex));
        appGridTooltipIndex = -1;

        Qt.callLater(function() {
            if (!root.appGridSearchActive || !root.searching) {
                return;
            }

            const refreshedCount = root.searchResultsModel ? root.searchResultsModel.count : 0;
            if (refreshedCount <= 0 || targetIndex >= refreshedCount) {
                return;
            }

            root.appGridTooltipIndex = targetIndex;
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

    function selectScreen(index, pinPreview) {
        selectedScreenIndex = index;
        screenPreviewPinned = pinPreview;
        refreshWindowModels();
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

    function taskBelongsToScreen(row, screenGeometry) {
        if (!screenGeometry || screenGeometry.width <= 0 || screenGeometry.height <= 0) {
            return false;
        }

        if (desktopTaskData(row, TaskManager.AbstractTasksModel.SkipTaskbar) || isDashboardTask(desktopWindowsModel, row)) {
            return false;
        }

        const geometry = desktopTaskData(row, TaskManager.AbstractTasksModel.Geometry);
        const clippedGeometry = intersectRects(geometry, screenGeometry);
        return clippedGeometry.width > 0 && clippedGeometry.height > 0;
    }

    function desktopWindowIndexes(desktopId) {
        const indexes = [];
        const previewScreenGeometry = activePreviewScreenGeometry;

        for (let row = 0; row < desktopWindowsModel.count; ++row) {
            const geometry = desktopTaskData(row, TaskManager.AbstractTasksModel.Geometry);
            const clippedGeometry = intersectRects(geometry, previewScreenGeometry);

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
        const previewScreenGeometry = activePreviewScreenGeometry;
        const geometry = desktopTaskData(row, TaskManager.AbstractTasksModel.Geometry);
        const clippedGeometry = intersectRects(geometry, previewScreenGeometry);

        if (clippedGeometry.width <= 0 || clippedGeometry.height <= 0 || previewScreenGeometry.width <= 0 || previewScreenGeometry.height <= 0) {
            return Qt.rect(0, 0, 0, 0);
        }

        const localX = clippedGeometry.x - previewScreenGeometry.x;
        const localY = clippedGeometry.y - previewScreenGeometry.y;
        const scaleX = previewWidth / previewScreenGeometry.width;
        const scaleY = previewHeight / previewScreenGeometry.height;

        return Qt.rect(
            Math.round(localX * scaleX),
            Math.round(localY * scaleY),
            Math.max(10, Math.round(clippedGeometry.width * scaleX)),
            Math.max(8, Math.round(clippedGeometry.height * scaleY))
        );
    }

    function screenWindowIndexes(screenName) {
        const indexes = [];
        const screenGeometry = screenGeometryAt(screenIndexByName(screenName));

        for (let row = 0; row < desktopWindowsModel.count; ++row) {
            if (taskBelongsToScreen(row, screenGeometry)) {
                indexes.push(row);
            }
        }

        return indexes;
    }

    function screenWindowCount(screenName) {
        return screenWindowIndexes(screenName).length;
    }

    function screenWindowPreviewRect(row, screenGeometry, previewWidth, previewHeight) {
        const geometry = desktopTaskData(row, TaskManager.AbstractTasksModel.Geometry);
        const clippedGeometry = intersectRects(geometry, screenGeometry);

        if (clippedGeometry.width <= 0 || clippedGeometry.height <= 0 || screenGeometry.width <= 0 || screenGeometry.height <= 0) {
            return Qt.rect(0, 0, 0, 0);
        }

        const localX = clippedGeometry.x - screenGeometry.x;
        const localY = clippedGeometry.y - screenGeometry.y;
        const scaleX = previewWidth / screenGeometry.width;
        const scaleY = previewHeight / screenGeometry.height;

        return Qt.rect(
            Math.round(localX * scaleX),
            Math.round(localY * scaleY),
            Math.max(8, Math.round(clippedGeometry.width * scaleX)),
            Math.max(6, Math.round(clippedGeometry.height * scaleY))
        );
    }

    function registerDesktopCard(index, item) {
        const cards = (root.desktopCardRefs || []).slice();
        cards[index] = item;
        root.desktopCardRefs = cards;
    }

    function registerScreenCard(index, item) {
        const cards = (root.screenCardRefs || []).slice();
        cards[index] = item;
        root.screenCardRefs = cards;
    }

    function unregisterScreenCard(index, item) {
        const cards = (root.screenCardRefs || []).slice();
        if (cards[index] === item) {
            cards[index] = null;
            root.screenCardRefs = cards;
        }
    }

    function screenCardAtPosition(x, y) {
        const view = root.fullViewRef;
        const cards = root.screenCardRefs || [];
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
        const screenCard = desktopCard ? null : screenCardAtPosition(x, y);
        dragTargetDesktopId = desktopCard ? desktopCard.desktopId : "";
        dragTargetScreenName = screenCard ? screenCard.screenName : "";
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

    function buildMoveWindowToScreenCommand(modelIndex, screenName) {
        const geometry = windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.Geometry);
        const payload = {
            targetOutputName: String(screenName || ""),
            pid: Number(windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.AppPid) || 0),
            appId: String(windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.AppId) || ""),
            caption: String(windowsModel.data(modelIndex, Qt.DisplayRole) || ""),
            x: Math.round(geometry ? geometry.x : 0),
            y: Math.round(geometry ? geometry.y : 0),
            width: Math.round(geometry ? geometry.width : 0),
            height: Math.round(geometry ? geometry.height : 0)
        };
        const script = [
            "const moveData = " + JSON.stringify(payload) + ";",
            "function normalizeDesktopFileName(value) {",
            "    const text = String(value || '');",
            "    const slashIndex = text.lastIndexOf('/');",
            "    const baseName = slashIndex >= 0 ? text.slice(slashIndex + 1) : text;",
            "    return baseName.endsWith('.desktop') ? baseName.slice(0, -8) : baseName;",
            "}",
            "function captionMatches(actual, expected) {",
            "    const actualText = String(actual || '');",
            "    const expectedText = String(expected || '');",
            "    return expectedText.length === 0 || actualText === expectedText || actualText.indexOf(expectedText) >= 0 || expectedText.indexOf(actualText) >= 0;",
            "}",
            "function scoreWindow(window) {",
            "    if (!window || window.deleted || window.specialWindow || !window.moveableAcrossScreens) {",
            "        return Number.POSITIVE_INFINITY;",
            "    }",
            "",
            "    if (moveData.pid > 0 && window.pid !== moveData.pid) {",
            "        return Number.POSITIVE_INFINITY;",
            "    }",
            "",
            "    const frameGeometry = window.frameGeometry;",
            "    if (!frameGeometry) {",
            "        return Number.POSITIVE_INFINITY;",
            "    }",
            "",
            "    let score = Math.abs(Math.round(frameGeometry.x) - moveData.x)",
            "        + Math.abs(Math.round(frameGeometry.y) - moveData.y)",
            "        + Math.abs(Math.round(frameGeometry.width) - moveData.width)",
            "        + Math.abs(Math.round(frameGeometry.height) - moveData.height);",
            "",
            "    if (!captionMatches(window.caption, moveData.caption)) {",
            "        score += 1000;",
            "    }",
            "",
            "    const desktopFileName = normalizeDesktopFileName(window.desktopFileName);",
            "    if (moveData.appId.length > 0 && desktopFileName.length > 0 && desktopFileName !== moveData.appId) {",
            "        score += 500;",
            "    }",
            "",
            "    return score;",
            "}",
            "let targetOutput = null;",
            "const outputs = workspace.screens || [];",
            "for (let index = 0; index < outputs.length; ++index) {",
            "    const output = outputs[index];",
            "    if (output && output.name === moveData.targetOutputName) {",
            "        targetOutput = output;",
            "        break;",
            "    }",
            "}",
            "if (targetOutput) {",
            "    let bestWindow = null;",
            "    let bestScore = Number.POSITIVE_INFINITY;",
            "    const windows = workspace.stackingOrder || [];",
            "    for (let index = 0; index < windows.length; ++index) {",
            "        const window = windows[index];",
            "        const score = scoreWindow(window);",
            "        if (isFinite(score) && score < bestScore) {",
            "            bestScore = score;",
            "            bestWindow = window;",
            "        }",
            "    }",
            "",
            "    if (bestWindow && bestWindow.output !== targetOutput) {",
            "        workspace.sendClientToScreen(bestWindow, targetOutput);",
            "    }",
            "}"
        ].join("\n");
        const pluginName = "dashlaunch_move_window_" + Date.now() + "_" + Math.floor(Math.random() * 100000);

        return "tmp=$(mktemp /tmp/dashlaunch-move-window-XXXXXX.js) && printf '%s' " + shellQuote(script)
            + " > \"$tmp\" && qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \"$tmp\" " + shellQuote(pluginName)
            + " >/dev/null && qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null && qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript " + shellQuote(pluginName)
            + " >/dev/null; rm -f \"$tmp\"";
    }

    function moveWindowToScreen(modelIndex, screenName) {
        if (!modelIndex || !modelIndex.valid || !screenName) {
            return false;
        }

        const targetScreenIndex = screenIndexByName(screenName);
        if (targetScreenIndex < 0) {
            return false;
        }

        const targetGeometry = screenGeometryAt(targetScreenIndex);
        const currentGeometry = windowsModel.data(modelIndex, TaskManager.AbstractTasksModel.ScreenGeometry);
        if (sameRect(currentGeometry, targetGeometry)) {
            return false;
        }

        const command = buildMoveWindowToScreenCommand(modelIndex, screenName);
        screenMoveRunner.disconnectSource(command);
        screenMoveRunner.connectSource(command);
        return true;
    }

    function finishWindowDrag() {
        if (!dragging) {
            resetDragState();
            return false;
        }

        const moved = dragTargetDesktopId
            ? moveWindowToDesktop(draggedTaskModelIndex, dragTargetDesktopId)
            : (dragTargetScreenName ? moveWindowToScreen(draggedTaskModelIndex, dragTargetScreenName) : false);
        if (moved) {
            suppressAutoCloseOnDragDrop = true;
            holdDashboardOpenAfterDrag();
            Qt.callLater(function() {
                if (dashboardWindow.visible) {
                    dashboardWindow.requestActivate();
                    Qt.callLater(root.focusDashboardView);
                }
            });
        }
        resetDragState();
        return moved;
    }

    onDashboardVisibleChanged: {
        if (!root.dashboardVisible) {
            pendingInitialWindowFocus = false;
            suppressHoverSelectionOnOpen = false;
            suppressAutoCloseOnDragDrop = false;
            desktopPreviewPinned = false;
            screenPreviewPinned = false;
            navigationSection = "windows";
            clearSearch();
            resetDragState();
            return;
        }

        pendingInitialWindowFocus = true;
        suppressHoverSelectionOnOpen = true;
        updateCurrentScreenGeometry();
        syncScreenSelection(true);
        refreshWindowModels();
        syncDesktopSelection(true);
        focusInitialSelection();
        Qt.callLater(updateCurrentScreenGeometry);
        Qt.callLater(refreshDesktopPreviews);
        Qt.callLater(focusDashboardView);
        Qt.callLater(applyPendingInitialWindowFocus);
    }

    onExpandedChanged: {
        if (root.expanded) {
            root.expanded = false;
            root.toggleDashboard();
        }
    }

    onKeepOpenAfterDragChanged: {
        // Ending drag grace should not force-close the dashboard; only explicit
        // focus changes outside the drag flow should close it.
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

    onPreviewScreenNameChanged: {
        windowsModel.invalidate();
        syncWindowSelection();
        refreshWindowGridLayout();
        refreshDesktopPreviews();
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
        refreshSelectedAppTooltip();
        if (!searching && fullViewRef && searchFieldRef && searchFieldRef.activeFocus) {
            fullViewRef.forceActiveFocus();
        }
    }

    onSelectedSearchIndexChanged: refreshSelectedAppTooltip()

    onAppGridSearchActiveChanged: refreshSelectedAppTooltip()

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

    Connections {
        target: root.searchResultsModel
        ignoreUnknownSignals: true

        function onCountChanged() {
            root.refreshSelectedAppTooltip();
        }

        function onDataChanged() {
            root.refreshSelectedAppTooltip();
        }

        function onModelReset() {
            root.refreshSelectedAppTooltip();
        }

        function onRowsInserted() {
            root.refreshSelectedAppTooltip();
        }

        function onRowsRemoved() {
            root.refreshSelectedAppTooltip();
        }

        function onLayoutChanged() {
            root.refreshSelectedAppTooltip();
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

    Plasma5Support.DataSource {
        id: activeOutputQuery
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            root.handleFollowMouseMonitorResult(data.stdout);
        }
    }

    Plasma5Support.DataSource {
        id: screenMoveRunner
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            root.refreshWindowModels();
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
        filterByScreen: root.filterCurrentMonitor || root.previewingScreenWindows
        screenGeometry: root.activePreviewScreenGeometry
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
        filterByScreen: false
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
            onClicked: root.toggleDashboard()
        }
    }

    Component {
        id: dashboardContentComponent
        Components.DashboardContent {
            root: root
            virtualDesktopInfo: virtualDesktopInfo
            windowsModel: windowsModel
            desktopWindowsModel: desktopWindowsModel
        }
    }

    Window {
        id: dashboardWindow
        visible: root.dashboardWindowVisible
        flags: root.fullscreenMode ? (Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint) : (Qt.Window | Qt.FramelessWindowHint)
        color: "transparent"
        title: Plasmoid.title

        onActiveChanged: {
            if (!active && visible && root.suppressAutoCloseOnDragDrop) {
                root.suppressAutoCloseOnDragDrop = false;
                return;
            }

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
                root.applyDashboardWindowMode();
                requestActivate();
                root.startDashboardContentFadeIn();
                Qt.callLater(root.focusDashboardView);
            }
        }

        Timer {
            id: dashboardHideTimer
            interval: root.dashboardFadeDuration
            repeat: false
            onTriggered: {
                if (!root.dashboardVisible) {
                    root.dashboardWindowVisible = false;
                }
            }
        }

        Connections {
            target: Plasmoid.configuration
            function onFullscreenModeChanged() {
                if (dashboardWindow.visible) {
                    root.applyDashboardWindowPlacement();
                }
            }
        }

        Shortcut {
            context: Qt.WindowShortcut
            enabled: dashboardWindow.visible
            sequence: "Escape"
            onActivated: root.handleEscape()
        }

        Loader {
            id: dashboardContentLoader
            anchors.fill: parent
            active: dashboardWindow.visible
            sourceComponent: dashboardContentComponent

            onLoaded: root.startDashboardContentFadeIn()
        }
    }

    fullRepresentation: Item {
        implicitWidth: 0
        implicitHeight: 0
    }
}
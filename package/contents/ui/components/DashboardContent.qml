pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

FocusScope {
    id: view

    required property var root
    required property var virtualDesktopInfo
    required property var windowsModel
    required property var desktopWindowsModel

    component PreviewTile: Rectangle {
        required property bool hovered
        required property bool selected
        required property bool previewing
        required property bool current
        required property bool dragTarget
        default property alias content: contentLayout.data

        radius: Kirigami.Units.cornerRadius
        color: hovered || dragTarget || selected || previewing || current
            ? Qt.rgba(1, 1, 1, 0.08)
            : "transparent"
        border.width: selected ? 1.8 : 0
        border.color: selected
            ? root.selectionBorderColor
            : "transparent"

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
        }
    }

    anchors.fill: parent
    focus: root.dashboardVisible
    opacity: root.dashboardContentVisible ? 1.0 : 0.0

    Component.onCompleted: {
        root.fullViewRef = view
        Qt.callLater(root.focusDashboardView)
    }

    Component.onDestruction: {
        if (root.fullViewRef === view) {
            root.fullViewRef = null
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.dashboardFadeDuration
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
        root.handleEscape()
        event.accepted = true
    }

    Keys.onPressed: event => {
        if (root.handleNavigationKey(event)) {
            return
        }

        if (root.searchFieldRef && root.searchFieldRef.activeFocus) {
            return
        }

        if ((event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0) {
            return
        }

        if (event.text && event.text.length > 0) {
            root.searchText += event.text
            Qt.callLater(root.focusSearchField)
            event.accepted = true
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        propagateComposedEvents: true

        onPositionChanged: {
            root.suppressHoverSelectionOnOpen = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

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
                    Layout.preferredHeight: (root.screenCount() > 0 || virtualDesktopInfo.desktopIds.length > 0)
                        ? root.desktopPreviewHeight + (Kirigami.Units.gridUnit * 2.7)
                        : 0
                    visible: root.screenCount() > 0 || virtualDesktopInfo.desktopIds.length > 0

                    RowLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.largeSpacing

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 3
                            Layout.fillHeight: true
                            visible: root.screenCount() > 0

                            Item {
                                anchors.fill: parent
                                clip: true

                                Repeater {
                                    model: root.screenCount()

                                    delegate: PreviewTile {
                                            id: screenCard
                                            required property int index
                                            readonly property string screenName: root.screenNameAt(index)
                                            readonly property rect screenGeometry: root.screenGeometryAt(index)
                                            readonly property rect tileRect: root.screenTileRectAt(index, parent.width, parent.height, Math.round(Kirigami.Units.gridUnit * 1.8), Kirigami.Units.smallSpacing)
                                            readonly property bool isCurrentScreen: index === root.currentDashboardScreenIndex()
                                            readonly property bool isPreviewing: root.previewScreenName === screenName
                                            readonly property bool isSelected: !root.searching && root.selectedScreenIndex === index
                                            readonly property bool isDragTarget: root.dragging && root.dragTargetScreenName === screenName
                                            readonly property int previewWindowCount: {
                                                root.desktopPreviewRevision
                                                return root.screenWindowCount(screenName)
                                            }

                                            hovered: screenMouseArea.containsMouse
                                            selected: isSelected
                                            previewing: isPreviewing
                                            current: isCurrentScreen
                                            dragTarget: isDragTarget

                                            x: tileRect.x
                                            y: tileRect.y
                                            width: tileRect.width
                                            height: tileRect.height + Math.round(Kirigami.Units.gridUnit * 1.8)
                                            Component.onCompleted: root.registerScreenCard(index, screenCard)
                                            Component.onDestruction: root.unregisterScreenCard(index, screenCard)

                                            Item {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: screenCard.tileRect.height

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: Kirigami.Units.cornerRadius
                                                    color: Qt.rgba(1, 1, 1, 0.035)
                                                    border.color: Qt.rgba(1, 1, 1, screenCard.isCurrentScreen ? 0.12 : 0.06)
                                                }

                                                Kirigami.Icon {
                                                    anchors.centerIn: parent
                                                    width: Math.round(Math.min(parent.width, parent.height) * 0.8)
                                                    height: width
                                                    source: "monitor"
                                                    opacity: screenCard.isSelected || screenCard.isPreviewing || screenCard.isCurrentScreen ? 0.9 : 0.75
                                                    color: screenCard.isSelected || screenCard.isPreviewing || screenCard.isCurrentScreen
                                                        ? root.selectionBorderColor
                                                        : root.mutedTextColor
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Kirigami.Units.smallSpacing

                                                PlasmaComponents3.Label {
                                                    Layout.fillWidth: true
                                                    color: screenCard.isSelected
                                                        ? root.selectionBorderColor
                                                        : root.textColor
                                                    elide: Text.ElideRight
                                                    font.weight: screenCard.isSelected ? Font.Bold : Font.Normal
                                                    text: root.screenLabelAt(index)
                                                }

                                                PlasmaComponents3.Label {
                                                    color: screenCard.isSelected
                                                        ? root.selectionBorderColor
                                                        : root.mutedTextColor
                                                    text: screenCard.previewWindowCount
                                                }
                                            }

                                            MouseArea {
                                                id: screenMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectScreen(index, true)
                                            }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 7
                            Layout.fillHeight: true
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
                                        model: virtualDesktopInfo.desktopIds.length + 1
                                        boundsBehavior: Flickable.StopAtBounds
                                        readonly property real centeredContentWidth: Math.max(0, (count * root.desktopPreviewWidth) + (Math.max(0, count - 1) * spacing))
                                        readonly property real sideMargin: Math.max(0, (width - centeredContentWidth) / 2)
                                        leftMargin: sideMargin
                                        rightMargin: sideMargin

                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0) {
                                                positionViewAtIndex(currentIndex, ListView.Contain)
                                            }
                                        }

                                        delegate: PreviewTile {
                                            id: desktopCard
                                            required property int index
                                            readonly property bool isCreateTile: index === virtualDesktopInfo.desktopIds.length
                                            readonly property string desktopId: isCreateTile ? "" : root.desktopIdAt(index)
                                            readonly property bool isCurrentDesktop: !isCreateTile && desktopId === virtualDesktopInfo.currentDesktop
                                            readonly property bool isPreviewing: !isCreateTile && root.previewDesktopId === desktopId
                                            readonly property bool isSelected: !isCreateTile && !root.searching && root.selectedDesktopIndex === index
                                            readonly property bool isDragTarget: !isCreateTile && root.dragging && root.dragTargetDesktopId === desktopId
                                            readonly property bool canRemoveDesktop: !isCreateTile && virtualDesktopInfo.desktopIds.length > 1
                                            readonly property int removalWindowCount: isCreateTile ? 0 : root.desktopTotalWindowCount(desktopId)
                                            readonly property int previewWindowCount: {
                                                if (isCreateTile) {
                                                    return 0
                                                }

                                                root.desktopPreviewRevision
                                                return root.desktopWindowCount(desktopId)
                                            }

                                            hovered: desktopMouseArea.containsMouse
                                            selected: isSelected
                                            previewing: isPreviewing
                                            current: isCurrentDesktop
                                            dragTarget: isDragTarget

                                            width: root.desktopPreviewWidth
                                            height: root.desktopPreviewHeight + (Kirigami.Units.gridUnit * 1.8)

                                            Component.onCompleted: {
                                                if (!isCreateTile) {
                                                    root.registerDesktopCard(index, desktopCard)
                                                }
                                            }
                                            Component.onDestruction: {
                                                if (!isCreateTile) {
                                                    root.unregisterDesktopCard(index, desktopCard)
                                                }
                                            }

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
                                                    visible: !desktopCard.isCreateTile
                                                    model: root.dashboardVisible
                                                        ? (function() {
                                                            root.desktopPreviewRevision
                                                            return root.desktopWindowIndexes(desktopCard.desktopId)
                                                        })()
                                                        : []

                                                    delegate: Rectangle {
                                                        required property int modelData
                                                        readonly property rect previewRect: {
                                                            root.desktopPreviewRevision
                                                            return root.desktopWindowPreviewRect(modelData, parent.width, parent.height)
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

                                                Kirigami.Icon {
                                                    anchors.centerIn: parent
                                                    visible: desktopCard.isCreateTile
                                                    width: Math.round(Math.min(parent.width, parent.height) * 0.75)
                                                    height: width
                                                    source: "list-add"
                                                    color: root.textColor
                                                }

                                                PlasmaComponents3.Label {
                                                    anchors.centerIn: parent
                                                    visible: !desktopCard.isCreateTile && desktopCard.previewWindowCount === 0
                                                    color: root.mutedTextColor
                                                    text: i18n("Empty")
                                                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.78)
                                                }

                                                Rectangle {
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: Kirigami.Units.smallSpacing
                                                    visible: desktopCard.canRemoveDesktop
                                                    z: 10
                                                    width: Kirigami.Units.gridUnit * 1.6
                                                    height: width
                                                    radius: width / 2
                                                    color: closeDesktopMouseArea.containsMouse
                                                        ? Qt.rgba(1, 1, 1, 0.16)
                                                        : Qt.rgba(1, 1, 1, 0.08)
                                                    border.width: 1
                                                    border.color: Qt.rgba(1, 1, 1, 0.12)

                                                    Kirigami.Icon {
                                                        anchors.centerIn: parent
                                                        width: Math.round(parent.width * 0.7)
                                                        height: width
                                                        source: "window-close"
                                                        color: root.textColor
                                                    }

                                                    MouseArea {
                                                        id: closeDesktopMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.LeftButton
                                                        preventStealing: true
                                                        propagateComposedEvents: false

                                                        onPressed: mouse.accepted = true

                                                        onClicked: {
                                                            if (desktopCard.removalWindowCount === 0) {
                                                                root.removeDesktop(desktopCard.desktopId, false)
                                                                mouse.accepted = true
                                                                return
                                                            }

                                                            mouse.accepted = true
                                                        }

                                                        onDoubleClicked: {
                                                            if (desktopCard.removalWindowCount > 0) {
                                                                root.removeDesktop(desktopCard.desktopId, true)
                                                            }
                                                            mouse.accepted = true
                                                        }
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Kirigami.Units.smallSpacing

                                                PlasmaComponents3.Label {
                                                    Layout.fillWidth: true
                                                    color: desktopCard.isSelected
                                                        ? root.selectionBorderColor
                                                        : root.textColor
                                                    elide: Text.ElideRight
                                                    font.weight: desktopCard.isSelected ? Font.Bold : Font.Normal
                                                    text: desktopCard.isCreateTile
                                                        ? i18n("Create desktop")
                                                        : root.desktopName(desktopCard.desktopId)
                                                }

                                                PlasmaComponents3.Label {
                                                    visible: !desktopCard.isCreateTile
                                                    color: desktopCard.isSelected
                                                        ? root.selectionBorderColor
                                                        : root.mutedTextColor
                                                    text: desktopCard.previewWindowCount
                                                }
                                            }

                                            MouseArea {
                                                id: desktopMouseArea
                                                anchors.fill: parent
                                                z: -1
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    if (desktopCard.isCreateTile) {
                                                        root.createDesktop()
                                                        return
                                                    }

                                                    root.selectDesktop(index, true)
                                                }

                                                onDoubleClicked: {
                                                    if (desktopCard.isCreateTile) {
                                                        return
                                                    }

                                                    root.selectDesktop(index, true)
                                                    root.triggerSelectedDesktop()
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.ToolButton {
                        id: viewToggleButton
                        Layout.preferredHeight: searchField.implicitHeight
                        Layout.maximumHeight: searchField.implicitHeight
                        focusPolicy: Qt.NoFocus
                        icon.name: root.appGridSearchActive ? "view-list-details" : "view-grid"
                        text: root.appGridSearchActive ? i18n("Show Windows") : i18n("Show apps")
                        display: QQC2.AbstractButton.TextBesideIcon
                        leftPadding: 10
                        rightPadding: 10
                        topPadding: Kirigami.Units.smallSpacing * 1.5
                        bottomPadding: Kirigami.Units.smallSpacing * 1.5

                        background: Rectangle {
                            radius: Kirigami.Units.cornerRadius
                            color: parent.down ? Qt.rgba(1, 1, 1, 0.16) : (parent.hovered ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                            border.color: parent.hovered ? root.selectionBorderColor : "transparent"
                            border.width: parent.hovered ? 1 : 0
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: width
                                source: viewToggleButton.icon.name
                            }

                            PlasmaComponents3.Label {
                                color: root.textColor
                                text: viewToggleButton.text
                            }
                        }

                        onClicked: root.toggleDashboardMode()

                        Accessible.name: text
                    }

                    QQC2.TextField {
                        id: searchField
                        Layout.preferredWidth: root.appGridSearchFieldWidth
                        Layout.maximumWidth: root.appGridSearchFieldWidth
                        text: root.searchText
                        color: root.textColor
                        placeholderText: i18n("Search applications")
                        selectByMouse: true

                        onTextEdited: root.searchText = text

                        Component.onCompleted: {
                            root.searchFieldRef = searchField
                        }

                        Component.onDestruction: {
                            if (root.searchFieldRef === searchField) {
                                root.searchFieldRef = null
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
                            root.handleNavigationKey(event)
                        }

                        Keys.onEscapePressed: event => {
                            root.handleEscape()
                            event.accepted = true
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    QQC2.ScrollView {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(parent.width * 0.6)
                        clip: true
                        visible: !root.appGridSearchActive
                        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                        GridView {
                            id: windowsGrid
                            anchors.fill: parent
                            model: root.visibleWindowRows()
                            currentIndex: root.selectedWindowIndex
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            cellWidth: Math.max(root.windowTileMinWidth, Math.min(root.windowTileMaxWidth, width / root.visibleWindowGridColumns()))
                            cellHeight: cellWidth * 0.68

                            function updateColumns() {
                                const idealWidth = root.searching ? 300 : 320
                                root.windowGridColumns = Math.max(1, Math.floor(Math.max(width, idealWidth) / idealWidth))
                            }

                            onWidthChanged: updateColumns()

                            Component.onCompleted: {
                                root.windowsGridRef = windowsGrid
                                currentIndex = root.selectedWindowIndex
                                updateColumns()
                            }

                            Component.onDestruction: {
                                if (root.windowsGridRef === windowsGrid) {
                                    root.windowsGridRef = null
                                }
                            }

                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    positionViewAtIndex(currentIndex, GridView.Contain)
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
                                            color: root.selectedWindowIndex === index
                                                ? root.selectionBorderColor
                                                : root.textColor
                                            elide: Text.ElideRight
                                            font.weight: root.selectedWindowIndex === index ? Font.Bold : Font.Normal
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
                                            return
                                        }

                                        root.selectedWindowIndex = index
                                        root.navigationSection = "windows"
                                    }
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    gesturePolicy: TapHandler.DragThreshold
                                    enabled: !root.dragging

                                    onTapped: {
                                        if (windowCard.dragConsumed) {
                                            windowCard.dragConsumed = false
                                            return
                                        }

                                        root.selectedWindowIndex = index
                                        root.navigationSection = "windows"
                                        root.activateWindow(index)
                                    }
                                }

                                TapHandler {
                                    acceptedButtons: Qt.MiddleButton
                                    gesturePolicy: TapHandler.DragThreshold
                                    enabled: !root.dragging

                                    onTapped: {
                                        if (windowCard.dragConsumed) {
                                            windowCard.dragConsumed = false
                                            return
                                        }

                                        root.selectedWindowIndex = index
                                        root.navigationSection = "windows"
                                        root.closeWindow(index)
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
                                            windowCard.dragConsumed = false
                                            root.selectedWindowIndex = index
                                            root.navigationSection = "windows"
                                            root.startWindowDrag(index, windowCard, centroid.position.x, centroid.position.y)
                                            return
                                        }

                                        if (root.draggedWindowRow === index) {
                                            root.continueWindowDrag(windowCard, centroid.position.x, centroid.position.y)
                                            root.finishWindowDrag()
                                        }
                                    }

                                    onTranslationChanged: {
                                        if (!active || root.draggedWindowRow !== index) {
                                            return
                                        }

                                        windowCard.dragConsumed = true
                                        root.continueWindowDrag(windowCard, centroid.position.x, centroid.position.y)
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
                    SearchResultsView {
                        id: searchResultsView
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(parent.width * 0.6)
                        visible: root.appGridSearchActive
                        resultsModel: root.appGridResultsModel
                        selectedIndex: root.selectedSearchIndex
                        tooltipIndex: root.appGridTooltipIndex
                        textColor: root.textColor
                        mutedTextColor: root.mutedTextColor
                        surfaceHoverColor: root.surfaceHoverColor
                        borderColor: root.borderColor
                        selectionBorderColor: root.selectionBorderColor
                        minCellWidth: root.appGridMinCellWidth
                        maxCellWidth: root.appGridMaxCellWidth
                        iconSize: root.appGridIconSize
                        tileSpacing: root.appGridTileSpacing
                        cellAspectRatio: root.appGridCellAspectRatio
                        resultsPadding: root.appGridResultsPadding
                        categoryLabel: root.searchResultCategoryLabel
                        categoryLookupRevision: root.searchResultCategoryRevision
                        showName: root.searchResultShowName
                        showCategoryHeader: root.searchResultShowCategoryHeader

                        Component.onCompleted: {
                            if (visible) {
                                root.searchResultsViewRef = searchResultsView
                            }
                        }

                        Component.onDestruction: {
                            if (root.searchResultsViewRef === searchResultsView) {
                                root.searchResultsViewRef = null
                            }
                        }

                        onVisibleChanged: {
                            if (visible) {
                                root.searchResultsViewRef = searchResultsView
                            } else if (root.searchResultsViewRef === searchResultsView) {
                                root.searchResultsViewRef = null
                            }
                        }

                        onResultActivated: index => {
                            root.selectedSearchIndex = index
                            root.triggerSelectedSearchResult()
                        }
                    }
                }
            }
        }
    }
}

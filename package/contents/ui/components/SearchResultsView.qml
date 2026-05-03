pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import "SearchResultsUtils.js" as SearchResultsUtils

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    required property var resultsModel
    required property int selectedIndex
    required property color textColor
    required property color mutedTextColor
    required property color surfaceHoverColor
    required property var categoryLabel
    required property int categoryLookupRevision
    property color borderColor: "transparent"
    property color selectionBorderColor: textColor
    property int tooltipIndex: -1
    property int minCellWidth: Kirigami.Units.gridUnit * 8
    property int maxCellWidth: minCellWidth
    property int iconSize: Kirigami.Units.iconSizes.medium
    property int tileSpacing: Kirigami.Units.smallSpacing
    property real cellAspectRatio: 1.0
    property int resultsPadding: 0
    property bool showName: true
    property bool showCategoryHeader: true
    signal resultActivated(int index)

    readonly property bool emptyResults: !resultsModel || resultsModel.count === 0
    readonly property int responsiveColumns: {
        const count = resultsModel ? resultsModel.count : 0
        const availableWidth = Math.max(1, width - (resultsPadding * 2))
        const maxColumns = Math.max(1, Math.floor(availableWidth / Math.max(1, minCellWidth)))
        return Math.max(1, Math.min(count > 0 ? count : 1, maxColumns))
    }
    readonly property var processedGroups: {
        root.categoryLookupRevision
        return SearchResultsUtils.processedResults(
            root.resultsModel,
            root.categoryLabel,
            i18n("Other")
        )
    }
    readonly property var displayedIndexes: {
        const indexes = []

        for (const group of root.processedGroups) {
            for (const item of group.items) {
                indexes.push(item.index)
            }
        }

        return indexes
    }
    readonly property var layoutEntries: {
        const entries = []

        const columns = Math.max(1, root.responsiveColumns)
        let rowOffset = 0

        for (const group of root.processedGroups) {
            const items = group.items || []
            for (let itemIndex = 0; itemIndex < items.length; ++itemIndex) {
                entries.push({
                    index: items[itemIndex].index,
                    row: rowOffset + Math.floor(itemIndex / columns),
                    column: itemIndex % columns
                })
            }

            rowOffset += Math.max(1, Math.ceil(items.length / columns))
        }

        return entries
    }
    property var itemRefs: ({})

    function nameText(itemData) {
        return SearchResultsUtils.normalizedText(itemData && itemData.display)
    }

    function descriptionText(itemData) {
        return SearchResultsUtils.descriptionText(itemData)
    }

    function typeText(itemData) {
        root.categoryLookupRevision
        return SearchResultsUtils.categoryText(itemData, root.categoryLabel)
            || i18n("Uncategorized")
    }

    function tooltipText(itemData) {
        return descriptionText(itemData)
    }

    function entryForIndex(index) {
        for (const entry of root.layoutEntries) {
            if (entry.index === index) {
                return entry
            }
        }

        return root.layoutEntries.length > 0 ? root.layoutEntries[0] : null
    }

    function nextHorizontalIndex(step) {
        if (root.displayedIndexes.length <= 0) {
            return -1
        }

        const currentOrder = Math.max(0, root.displayedIndexes.indexOf(root.selectedIndex))
        const targetOrder = Math.max(0, Math.min(root.displayedIndexes.length - 1, currentOrder + step))
        return root.displayedIndexes[targetOrder]
    }

    function nextVerticalIndex(step) {
        if (root.displayedIndexes.length <= 0) {
            return -1
        }

        if (root.layoutEntries.length <= 0) {
            return -1
        }

        const currentEntry = entryForIndex(root.selectedIndex)
        if (!currentEntry) {
            return -1
        }

        let maxRow = 0
        for (const entry of root.layoutEntries) {
            maxRow = Math.max(maxRow, entry.row)
        }

        const targetRow = Math.max(0, Math.min(maxRow, currentEntry.row + step))
        let bestEntry = null
        let bestDelta = Number.MAX_SAFE_INTEGER

        for (const entry of root.layoutEntries) {
            if (entry.row !== targetRow) {
                continue
            }

            const delta = Math.abs(entry.column - currentEntry.column)
            if (!bestEntry || delta < bestDelta || (delta === bestDelta && entry.column < bestEntry.column)) {
                bestEntry = entry
                bestDelta = delta
            }
        }

        return bestEntry ? bestEntry.index : currentEntry.index
    }

    function registerItemRef(index, item) {
        const updatedRefs = Object.assign({}, root.itemRefs)
        updatedRefs[index] = item
        root.itemRefs = updatedRefs
    }

    function unregisterItemRef(index, item) {
        if (!root.itemRefs[index] || root.itemRefs[index] !== item) {
            return
        }

        const updatedRefs = Object.assign({}, root.itemRefs)
        delete updatedRefs[index]
        root.itemRefs = updatedRefs
    }

    function ensureIndexVisible(index) {
        const flickable = scrollView.contentItem
        if (!flickable) {
            return
        }

        const item = root.itemRefs[index]
        if (!item) {
            return
        }

        const itemTop = item.mapToItem(contentColumn, 0, 0).y
        const itemBottom = itemTop + item.height
        const viewTop = flickable.contentY
        const viewBottom = viewTop + flickable.height

        if (itemTop < viewTop) {
            flickable.contentY = itemTop
        } else if (itemBottom > viewBottom) {
            flickable.contentY = Math.max(0, itemBottom - flickable.height)
        }
    }

    QQC2.ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: root.resultsPadding
        clip: true
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        Column {
            id: contentColumn
            width: Math.max(1, root.width - (root.resultsPadding * 2))
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.processedGroups

                delegate: Item {
                    required property var modelData
                    readonly property int groupCellWidth: Math.max(root.minCellWidth, Math.min(root.maxCellWidth, Math.floor(width / root.responsiveColumns)))
                    readonly property int visibleColumns: Math.max(1, Math.min(root.responsiveColumns, modelData.items ? modelData.items.length : 1))
                    readonly property int groupTileWidth: Math.max(1, groupCellWidth - root.tileSpacing)
                    readonly property int groupFlowWidth: Math.min(width, (visibleColumns * groupTileWidth) + (Math.max(0, visibleColumns - 1) * root.tileSpacing))

                    visible: (modelData.items || []).length > 0
                    width: parent ? parent.width : 0
                    height: sectionColumn.implicitHeight

                    Column {
                        id: sectionColumn
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        Loader {
                            property var groupData: modelData
                            property int groupCellWidth: parent.parent.groupCellWidth
                            property int groupTileWidth: parent.parent.groupTileWidth
                            property int groupFlowWidth: parent.parent.groupFlowWidth
                            width: parent.width
                            sourceComponent: gridGroupComponent
                        }
                    }
                }
            }
        }
    }

    PlasmaComponents3.Label {
        anchors.centerIn: parent
        color: root.mutedTextColor
        text: i18n("Nothing found")
        visible: root.emptyResults
    }

    Component {
        id: gridGroupComponent

        Flow {
            id: gridGroupRoot
            property var groupData: parent ? parent.groupData : null
            property int groupCellWidth: parent ? parent.groupCellWidth : root.minCellWidth
            property int groupTileWidth: parent ? parent.groupTileWidth : root.minCellWidth
            property int groupFlowWidth: parent ? parent.groupFlowWidth : width
            x: Math.max(0, Math.round((parent.width - width) / 2))
            width: gridGroupRoot.groupFlowWidth
            spacing: root.tileSpacing

            Repeater {
                model: gridGroupRoot.groupData ? gridGroupRoot.groupData.items : []

                delegate: Rectangle {
                    id: gridCard
                    required property var modelData
                    readonly property var itemData: modelData
                    readonly property string categoryTextValue: root.typeText(itemData)
                    readonly property string categoryIconSource: SearchResultsUtils.categoryIconName(categoryTextValue)
                    readonly property bool categoryHeaderVisible: root.showCategoryHeader && categoryTextValue.length > 0
                    readonly property int extraTextLineCount: (root.showName && root.nameText(itemData).length > 0 ? 1 : 0)
                        + (root.descriptionText(itemData).length > 0 ? 1 : 0)
                    readonly property int cardHeight: Math.max(
                        Kirigami.Units.gridUnit * 8,
                        Math.round(gridGroupRoot.groupCellWidth * root.cellAspectRatio)
                            + (((categoryHeaderVisible ? 1 : 0) + extraTextLineCount) > 0
                                ? (((categoryHeaderVisible ? 1 : 0) + extraTextLineCount) * Math.round(Kirigami.Units.gridUnit * 1.2))
                                : 0)
                    )

                    width: gridGroupRoot.groupTileWidth
                    height: Math.max(1, cardHeight - root.tileSpacing)
                    radius: Kirigami.Units.cornerRadius
                    color: resultMouseArea.containsMouse || root.selectedIndex === itemData.index ? root.surfaceHoverColor : "transparent"
                    border.width: root.selectedIndex === itemData.index ? 1.5 : 1
                    border.color: root.selectedIndex === itemData.index ? root.selectionBorderColor : root.borderColor

                    Component.onCompleted: root.registerItemRef(itemData.index, gridCard)
                    Component.onDestruction: root.unregisterItemRef(itemData.index, gridCard)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            visible: gridCard.categoryHeaderVisible
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                color: "#6f6f6f"
                                elide: Text.ElideRight
                                font.pixelSize: Math.max(Kirigami.Theme.defaultFont.pixelSize - 1, 10)
                                text: gridCard.categoryTextValue
                            }

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: width
                                source: gridCard.categoryIconSource
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: root.iconSize
                                height: root.iconSize
                                source: itemData.decoration
                            }
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.showName && root.nameText(itemData).length > 0
                            horizontalAlignment: Text.AlignHCenter
                            color: root.selectedIndex === itemData.index ? root.selectionBorderColor : root.textColor
                            elide: Text.ElideRight
                            font.weight: root.selectedIndex === itemData.index ? Font.Bold : Font.Normal
                            text: root.nameText(itemData)
                        }

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            visible: root.descriptionText(itemData).length > 0
                            horizontalAlignment: Text.AlignHCenter
                            color: root.mutedTextColor
                            elide: Text.ElideRight
                            text: root.descriptionText(itemData)
                        }

                    }

                    MouseArea {
                        id: resultMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        QQC2.ToolTip.visible: (containsMouse || root.tooltipIndex === itemData.index) && root.descriptionText(itemData).length > 0
                        QQC2.ToolTip.delay: containsMouse ? 300 : 0
                        QQC2.ToolTip.text: root.tooltipText(itemData)
                        onClicked: root.resultActivated(itemData.index)
                    }

                }
            }
        }
    }
}
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
    required property int tooltipIndex
    required property color textColor
    required property color mutedTextColor
    required property color surfaceHoverColor
    required property color borderColor
    required property color selectionBorderColor
    required property int minCellWidth
    required property int maxCellWidth
    required property int iconSize
    required property int tileSpacing
    required property real cellAspectRatio
    required property int resultsPadding
    required property var categoryLabel
    required property int categoryLookupRevision
    signal resultActivated(int index)

    readonly property int responsiveColumns: {
        const count = resultsModel ? resultsModel.count : 0
        const availableWidth = Math.max(1, width - (resultsPadding * 2))
        const maxColumns = Math.max(1, Math.floor(availableWidth / minCellWidth))
        return Math.max(1, Math.min(count > 0 ? count : 1, maxColumns))
    }
    readonly property bool emptyResults: !resultsModel || resultsModel.count === 0
    readonly property var groupedResults: {
        root.categoryLookupRevision
        return SearchResultsUtils.groupedResults(root.resultsModel, root.categoryLabel, i18n("Other"))
    }
    property var tileItemRefs: ({})
    readonly property var displayedIndexes: {
        const indexes = []

        for (const group of root.groupedResults) {
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

        for (const group of root.groupedResults) {
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

    function registerTileItem(index, item) {
        const updatedRefs = Object.assign({}, root.tileItemRefs)
        updatedRefs[index] = item
        root.tileItemRefs = updatedRefs
    }

    function unregisterTileItem(index, item) {
        if (!root.tileItemRefs[index] || root.tileItemRefs[index] !== item) {
            return
        }

        const updatedRefs = Object.assign({}, root.tileItemRefs)
        delete updatedRefs[index]
        root.tileItemRefs = updatedRefs
    }

    function ensureIndexVisible(index) {
        const flickable = scrollView.contentItem
        if (!flickable) {
            return
        }

        const entry = entryForIndex(index)
        if (entry && entry.row === 0) {
            flickable.contentY = 0
            return
        }

        const item = root.tileItemRefs[index]
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
                model: root.groupedResults

                delegate: Item {
                    required property var modelData
                    readonly property string title: modelData.title
                    readonly property int groupCellWidth: Math.max(root.minCellWidth, Math.min(root.maxCellWidth, Math.floor(width / root.responsiveColumns)))
                    readonly property int groupCellHeight: Math.max(Kirigami.Units.gridUnit * 8, Math.round(groupCellWidth * root.cellAspectRatio))

                    visible: title.length > 0
                    width: parent ? parent.width : 0
                    height: sectionColumn.implicitHeight

                    Column {
                        id: sectionColumn
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            width: parent.width
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: width
                                source: SearchResultsUtils.categoryIconName(title)
                            }

                            PlasmaComponents3.Label {
                                Layout.fillWidth: true
                                color: root.textColor
                                font.weight: Font.DemiBold
                                text: title
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: root.tileSpacing

                            Repeater {
                                model: modelData.items

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property var itemData: modelData

                                    width: Math.max(1, groupCellWidth - root.tileSpacing)
                                    height: Math.max(1, groupCellHeight - root.tileSpacing)
                                    radius: Kirigami.Units.cornerRadius
                                    color: resultMouseArea.containsMouse || root.selectedIndex === itemData.index ? root.surfaceHoverColor : "transparent"
                                    border.width: root.selectedIndex === itemData.index ? 1.5 : 1
                                    border.color: root.selectedIndex === itemData.index ? root.selectionBorderColor : root.borderColor

                                    Component.onCompleted: root.registerTileItem(itemData.index, this)
                                    Component.onDestruction: root.unregisterTileItem(itemData.index, this)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Kirigami.Units.largeSpacing
                                        spacing: Kirigami.Units.smallSpacing

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
                                            horizontalAlignment: Text.AlignHCenter
                                            color: root.textColor
                                            elide: Text.ElideRight
                                            text: itemData.display
                                        }
                                    }

                                    MouseArea {
                                        id: resultMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        QQC2.ToolTip.visible: (containsMouse || root.tooltipIndex === itemData.index) && (itemData.description.length > 0)
                                        QQC2.ToolTip.delay: containsMouse ? 300 : 0
                                        QQC2.ToolTip.text: itemData.description
                                        onClicked: root.resultActivated(itemData.index)
                                    }
                                }
                            }
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
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

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
    signal resultActivated(int index)

    readonly property bool hasSections: !!(resultsModel && resultsModel.sections && resultsModel.sections.count > 0)
    readonly property int responsiveColumns: {
        const count = resultsModel ? resultsModel.count : 0
        const availableWidth = Math.max(1, width - (resultsPadding * 2))
        const maxColumns = Math.max(1, Math.floor(availableWidth / minCellWidth))
        return Math.max(1, Math.min(count > 0 ? count : 1, maxColumns))
    }

    function sectionTitle(sectionIndex) {
        if (!resultsModel || !resultsModel.sections) {
            return ""
        }

        const modelIndex = resultsModel.sections.index(sectionIndex, 0)
        if (!modelIndex.valid) {
            return ""
        }

        return String(resultsModel.sections.data(modelIndex, Qt.DisplayRole) || "")
    }

    function categoryText(matchModel) {
        return String((matchModel && matchModel.section) || "")
    }

    QQC2.ScrollView {
        anchors.fill: parent
        anchors.margins: root.resultsPadding
        clip: true
        visible: root.hasSections
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        Column {
            width: Math.max(1, root.width - (root.resultsPadding * 2))
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.resultsModel ? root.resultsModel.sections : null

                delegate: Item {
                    required property int index
                    readonly property string title: root.sectionTitle(index)
                    readonly property int groupCellWidth: Math.max(root.minCellWidth, Math.min(root.maxCellWidth, Math.floor(width / root.responsiveColumns)))
                    readonly property int groupCellHeight: Math.max(Kirigami.Units.gridUnit * 8, Math.round(groupCellWidth * root.cellAspectRatio))

                    visible: title.length > 0
                    width: parent ? parent.width : 0
                    height: sectionColumn.implicitHeight

                    Column {
                        id: sectionColumn
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            width: parent.width
                            color: root.textColor
                            font.weight: Font.DemiBold
                            text: title
                        }

                        Flow {
                            width: parent.width
                            spacing: root.tileSpacing

                            Repeater {
                                model: root.resultsModel

                                delegate: Rectangle {
                                    required property int index
                                    required property var model
                                    readonly property bool matchesSection: model.section === title

                                    visible: matchesSection
                                    width: matchesSection ? Math.max(1, groupCellWidth - root.tileSpacing) : 0
                                    height: matchesSection ? Math.max(1, groupCellHeight - root.tileSpacing) : 0
                                    radius: Kirigami.Units.cornerRadius
                                    color: resultMouseArea.containsMouse || root.selectedIndex === index ? root.surfaceHoverColor : "transparent"
                                    border.width: root.selectedIndex === index ? 1.5 : 1
                                    border.color: root.selectedIndex === index ? root.selectionBorderColor : root.borderColor

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
                                                source: model.decoration
                                            }
                                        }

                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            color: root.mutedTextColor
                                            elide: Text.ElideRight
                                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.78)
                                            text: root.categoryText(model)
                                            visible: text.length > 0
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
                                        id: resultMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        QQC2.ToolTip.visible: (containsMouse || root.tooltipIndex === index) && ((model.description || "").length > 0)
                                        QQC2.ToolTip.delay: containsMouse ? 300 : 0
                                        QQC2.ToolTip.text: model.description || ""
                                        onClicked: root.resultActivated(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    GridView {
        anchors.fill: parent
        anchors.margins: root.resultsPadding
        clip: true
        visible: !root.hasSections
        property int responsiveColumns: root.responsiveColumns
        cellWidth: Math.max(root.minCellWidth, Math.min(root.maxCellWidth, Math.floor(width / responsiveColumns)))
        cellHeight: Math.max(Kirigami.Units.gridUnit * 8, Math.round(cellWidth * root.cellAspectRatio))
        model: root.resultsModel
        currentIndex: root.selectedIndex
        boundsBehavior: Flickable.StopAtBounds

        onCurrentIndexChanged: {
            if (currentIndex >= 0) {
                positionViewAtIndex(currentIndex, GridView.Contain)
            }
        }

        delegate: Rectangle {
            required property int index
            required property var model

            width: Math.max(1, GridView.view.cellWidth - root.tileSpacing)
            height: Math.max(1, GridView.view.cellHeight - root.tileSpacing)
            radius: Kirigami.Units.cornerRadius
            color: resultMouseArea.containsMouse || root.selectedIndex === index ? root.surfaceHoverColor : "transparent"
            border.width: root.selectedIndex === index ? 1.5 : 1
            border.color: root.selectedIndex === index ? root.selectionBorderColor : root.borderColor

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
                        source: model.decoration
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: root.mutedTextColor
                    elide: Text.ElideRight
                    font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.78)
                    text: root.categoryText(model)
                    visible: text.length > 0
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
                id: resultMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                QQC2.ToolTip.visible: (containsMouse || root.tooltipIndex === index) && ((model.description || "").length > 0)
                QQC2.ToolTip.delay: containsMouse ? 300 : 0
                QQC2.ToolTip.text: model.description || ""
                onClicked: root.resultActivated(index)
            }
        }
    }

    PlasmaComponents3.Label {
        anchors.centerIn: parent
        color: root.mutedTextColor
        text: i18n("Nothing found")
        visible: !root.resultsModel || root.resultsModel.count === 0
    }
}

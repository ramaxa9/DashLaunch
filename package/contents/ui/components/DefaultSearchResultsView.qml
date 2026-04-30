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
    required property bool searching
    required property var categoryLabel
    required property int categoryLookupRevision
    signal resultActivated(int index)

    readonly property bool hasSections: SearchResultsUtils.hasSections(resultsModel)
    readonly property bool emptyResults: !resultsModel || resultsModel.count === 0
    readonly property string emptyResultsText: i18n("Nothing found")

    function secondaryText(matchModel) {
        root.categoryLookupRevision
        const category = SearchResultsUtils.categoryText(matchModel, root.categoryLabel)
        const description = String((matchModel && matchModel.description) || "")

        if (category.length > 0 && description.length > 0 && description !== category) {
            return category + " • " + description
        }

        if (category.length > 0) {
            return category
        }

        if (description.length > 0) {
            return description
        }

        return i18n("Launch application")
    }

    QQC2.ScrollView {
        anchors.fill: parent
        clip: true
        visible: root.hasSections
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        Column {
            width: root.width
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: root.resultsModel ? root.resultsModel.sections : null

                delegate: Item {
                    required property int index
                    readonly property string title: SearchResultsUtils.sectionTitle(root.resultsModel, index)

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

                        Repeater {
                            model: root.resultsModel

                            delegate: Rectangle {
                                required property int index
                                required property var model
                                readonly property bool matchesSection: model.section === title

                                visible: matchesSection
                                width: sectionColumn.width
                                height: matchesSection ? Kirigami.Units.gridUnit * 3.4 : 0
                                radius: Kirigami.Units.cornerRadius
                                color: resultMouseArea.containsMouse || root.selectedIndex === index ? root.surfaceHoverColor : "transparent"

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
                                            text: root.secondaryText(model)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: resultMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.resultActivated(index)
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.searching && root.emptyResults ? Kirigami.Units.gridUnit * 4 : 0

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    color: root.mutedTextColor
                    text: root.emptyResultsText
                    visible: parent.height > 0
                }
            }
        }
    }

    ListView {
        anchors.fill: parent
        clip: true
        spacing: Kirigami.Units.smallSpacing
        visible: !root.hasSections
        model: root.resultsModel
        currentIndex: root.selectedIndex

        onCurrentIndexChanged: {
            if (currentIndex >= 0) {
                positionViewAtIndex(currentIndex, ListView.Contain)
            }
        }

        delegate: Rectangle {
            required property int index
            required property var model

            width: ListView.view.width
            height: Kirigami.Units.gridUnit * 3.4
            radius: Kirigami.Units.cornerRadius
            color: resultMouseArea.containsMouse || root.selectedIndex === index ? root.surfaceHoverColor : "transparent"

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
                        text: root.secondaryText(model)
                    }
                }
            }

            MouseArea {
                id: resultMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resultActivated(index)
            }
        }

        footer: Item {
            width: ListView.view.width
            height: root.searching && root.emptyResults ? Kirigami.Units.gridUnit * 4 : 0

            PlasmaComponents3.Label {
                anchors.centerIn: parent
                color: root.mutedTextColor
                text: root.emptyResultsText
                visible: parent.height > 0
            }
        }
    }
}

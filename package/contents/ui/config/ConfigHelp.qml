import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    readonly property color sectionBackgroundColor: "#81d41a"
    readonly property color sectionTextColor: "#355269"
    readonly property color headerBackgroundColor: "#cccccc"
    readonly property color headerTextColor: "#3465a4"
    readonly property color bodyTextColor: Kirigami.Theme.textColor
    readonly property color tableBorderColor: "#000000"
    readonly property int tableBaseColumnWidth: Math.max(Kirigami.Units.gridUnit * 6, Math.floor(width / 6.5))
    readonly property var tableColumnWidths: [
        Math.round(tableBaseColumnWidth * 1.78),
        Math.round(tableBaseColumnWidth * 0.96),
        Math.round(tableBaseColumnWidth * 1.11),
        Math.round(tableBaseColumnWidth * 0.98)
    ]
    readonly property int tableTotalWidth: tableColumnWidths[0] + tableColumnWidths[1] + tableColumnWidths[2] + tableColumnWidths[3]
    readonly property int tableRowHeight: Math.max(Kirigami.Units.gridUnit * 1.1, 26)
    readonly property int tableCellPadding: 5

    component HelpTableCell: Rectangle {
        required property string text
        property bool header: false
        property bool section: false
        property bool rowTitle: false
        property int span: 1
        property int column: 0
        property bool spacer: false

        Layout.columnSpan: span
        Layout.preferredWidth: page.tableColumnWidths[column]
            + (span > 1
                ? (page.tableColumnWidths.slice(column + 1, column + span).reduce((sum, value) => sum + value, 0))
                : 0)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        implicitHeight: spacer ? page.tableRowHeight : Math.max(page.tableRowHeight, cellLabel.implicitHeight + (page.tableCellPadding * 2))
        color: spacer
            ? "transparent"
            : section
                ? page.sectionBackgroundColor
                : header || rowTitle
                    ? page.headerBackgroundColor
                    : "transparent"
        border.width: spacer ? 0 : 1
        border.color: page.tableBorderColor

        Label {
            id: cellLabel
            anchors.fill: parent
            anchors.margins: page.tableCellPadding
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            font.bold: header || section || rowTitle
            font.pixelSize: 11
            color: section ? page.sectionTextColor
                : header || rowTitle ? page.headerTextColor
                : page.bodyTextColor
            text: parent.text
            visible: !parent.spacer
        }
    }

    readonly property var mouseRows: [
        {
            label: i18n("Window tile"),
            single: i18n("Focus"),
            doubleAction: "",
            middle: i18n("Close")
        },
        {
            label: i18n("Desktop tile"),
            single: i18n("Filter windows"),
            doubleAction: i18n("Activate"),
            middle: ""
        },
        {
            label: i18n("Desktop tile close button"),
            single: i18n("Close"),
            doubleAction: i18n("Force close"),
            middle: ""
        },
        {
            label: i18n("Screen tile"),
            single: i18n("Filter windows"),
            doubleAction: "",
            middle: ""
        },
        {
            label: i18n("App list/grid"),
            single: i18n("Activate"),
            doubleAction: "",
            middle: ""
        }
    ]

    readonly property var keyboardRows: [
        {
            label: i18n("Window tile"),
            arrows: i18n("Navigate"),
            deleteAction: i18n("Close"),
            enter: i18n("Activate")
        },
        {
            label: i18n("Desktop tile"),
            arrows: i18n("Navigate"),
            deleteAction: "",
            enter: i18n("Activate")
        },
        {
            label: i18n("Screen tile"),
            arrows: "",
            deleteAction: "",
            enter: ""
        },
        {
            label: i18n("App list/grid"),
            arrows: i18n("Navigate"),
            deleteAction: "",
            enter: i18n("Activate")
        },
        {
            label: i18n("App search"),
            prompt: i18n("Start typing")
        }
    ]

    function displayValue(value) {
        return value && value.length > 0 ? value : "";
    }

    readonly property var tableCells: [
        { text: i18n("Mouse"), section: true, column: 0, span: 4 },

        { text: "", header: true, column: 0 },
        { text: i18n("Single click"), header: true, column: 1 },
        { text: i18n("Double click"), header: true, column: 2 },
        { text: i18n("Middle click"), header: true, column: 3 },

        { text: mouseRows[0].label, rowTitle: true, column: 0 },
        { text: displayValue(mouseRows[0].single), column: 1 },
        { text: displayValue(mouseRows[0].doubleAction), column: 2 },
        { text: displayValue(mouseRows[0].middle), column: 3 },

        { text: mouseRows[1].label, rowTitle: true, column: 0 },
        { text: displayValue(mouseRows[1].single), column: 1 },
        { text: displayValue(mouseRows[1].doubleAction), column: 2 },
        { text: displayValue(mouseRows[1].middle), column: 3 },

        { text: mouseRows[2].label, rowTitle: true, column: 0 },
        { text: displayValue(mouseRows[2].single), column: 1 },
        { text: displayValue(mouseRows[2].doubleAction), column: 2 },
        { text: displayValue(mouseRows[2].middle), column: 3 },

        { text: mouseRows[3].label, rowTitle: true, column: 0 },
        { text: displayValue(mouseRows[3].single), column: 1 },
        { text: displayValue(mouseRows[3].doubleAction), column: 2 },
        { text: displayValue(mouseRows[3].middle), column: 3 },

        { text: mouseRows[4].label, rowTitle: true, column: 0 },
        { text: displayValue(mouseRows[4].single), column: 1 },
        { text: displayValue(mouseRows[4].doubleAction), column: 2 },
        { text: displayValue(mouseRows[4].middle), column: 3 },

        { text: "", column: 0, span: 4, spacer: true },

        { text: i18n("Keyboard"), section: true, column: 0, span: 4 },

        { text: "", header: true, column: 0 },
        { text: i18n("Arrows"), header: true, column: 1 },
        { text: i18n("Delete"), header: true, column: 2 },
        { text: i18n("Enter"), header: true, column: 3 },

        { text: keyboardRows[0].label, rowTitle: true, column: 0 },
        { text: displayValue(keyboardRows[0].arrows), column: 1 },
        { text: displayValue(keyboardRows[0].deleteAction), column: 2 },
        { text: displayValue(keyboardRows[0].enter), column: 3 },

        { text: keyboardRows[1].label, rowTitle: true, column: 0 },
        { text: displayValue(keyboardRows[1].arrows), column: 1 },
        { text: displayValue(keyboardRows[1].deleteAction), column: 2 },
        { text: displayValue(keyboardRows[1].enter), column: 3 },

        { text: keyboardRows[2].label, rowTitle: true, column: 0 },
        { text: displayValue(keyboardRows[2].arrows), column: 1 },
        { text: displayValue(keyboardRows[2].deleteAction), column: 2 },
        { text: displayValue(keyboardRows[2].enter), column: 3 },

        { text: keyboardRows[3].label, rowTitle: true, column: 0 },
        { text: displayValue(keyboardRows[3].arrows), column: 1 },
        { text: displayValue(keyboardRows[3].deleteAction), column: 2 },
        { text: displayValue(keyboardRows[3].enter), column: 3 },

        { text: keyboardRows[4].label, rowTitle: true, column: 0 },
        { text: displayValue(keyboardRows[4].prompt), column: 1, span: 3 }
    ]

    Item {
        width: parent.width

        GridLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: page.tableTotalWidth
            columns: 4
            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: page.tableCells

                delegate: HelpTableCell {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.text
                    column: modelData.column || 0
                    span: modelData.span || 1
                    header: !!modelData.header
                    section: !!modelData.section
                    rowTitle: !!modelData.rowTitle
                    spacer: !!modelData.spacer
                }
            }
        }
    }
}
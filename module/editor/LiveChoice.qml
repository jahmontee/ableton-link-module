import QtQuick 2.11
import QtQuick.Templates 2.4 as T

T.ComboBox {
    id: control
    implicitWidth: 240; implicitHeight: 64
    leftPadding: 18; rightPadding: 46; topPadding: 8; bottomPadding: 8
    font.family: "Inter"; font.pixelSize: 21; font.weight: Font.DemiBold
    property int bottomClearance: 96
    opacity: enabled ? 1 : 0.5
    background: Rectangle { color: control.down ? "#474747" : "#323232"; radius: 3; border.color: "#121212" }
    contentItem: Text {
        text: control.displayText; font: control.font; color: "#ebebeb"
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - 34; y: (control.height - height) / 2
        text: "▾"; font.family: "Inter"; font.pixelSize: 23; color: "#9b9b9b"
    }
    delegate: T.ItemDelegate {
        width: control.width; height: 52; highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: control.textRole ? modelData[control.textRole] : modelData
            font.family: "Inter"; font.pixelSize: 20; font.weight: Font.Medium
            color: parent.highlighted ? "#121212" : "#ebebeb"; elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter; leftPadding: 18; rightPadding: 18
        }
        background: Rectangle { color: parent.highlighted ? "#ff9d00" : "#262626" }
    }
    popup: T.Popup {
        objectName: control.objectName + "_popup"
        y: control.height + 5; width: control.width
        height: Math.min(320, contentItem.implicitHeight + 4)
        topMargin: 16; bottomMargin: control.bottomClearance; padding: 2
        contentItem: ListView {
            clip: true; implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex; boundsBehavior: Flickable.StopAtBounds
        }
        background: Rectangle { color: "#262626"; radius: 3; border.width: 1; border.color: "#474747" }
    }
}

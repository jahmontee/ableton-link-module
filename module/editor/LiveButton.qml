import QtQuick 2.11
import QtQuick.Templates 2.4 as T

T.Button {
    id: control
    implicitWidth: 128; implicitHeight: 64
    property bool accent: false
    font.family: "Inter"; font.pixelSize: 21; font.weight: Font.Bold
    opacity: enabled ? 1 : 0.5
    hoverEnabled: true
    background: Rectangle {
        radius: 3; border.width: 1
        color: (control.checkable && control.checked) || control.accent ? (control.down ? "#ffad29" : "#ff9d00") : control.down ? "#474747" : control.hovered ? "#3d3d3d" : "#323232"
        border.color: (control.checkable && control.checked) || control.accent ? "#b87100" : control.hovered ? "#4a4a4a" : "#121212"
    }
    contentItem: Item {
        Text {
            x: 16; width: parent.width - (control.checkable ? 82 : 32); height: parent.height
            text: control.text; font: control.font; elide: Text.ElideRight
            color: (control.checkable && control.checked) || control.accent ? "#121212" : "#ebebeb"
            horizontalAlignment: control.checkable ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        Text {
            visible: control.checkable; anchors.right: parent.right; anchors.rightMargin: 16; height: parent.height
            text: control.checked ? "ON" : "OFF"; font: control.font
            color: control.checked ? "#121212" : "#9b9b9b"; verticalAlignment: Text.AlignVCenter
        }
    }
}

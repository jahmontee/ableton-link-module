import QtQuick 2.11
import QtQuick.Templates 2.4 as T

T.SpinBox {
    id: control
    implicitWidth: 250; implicitHeight: 64
    leftPadding: 64; rightPadding: 64; topPadding: 8; bottomPadding: 8
    font.family: "Inter"; font.pixelSize: 27; font.weight: Font.Bold
    property bool typing: false
    editable: true; opacity: enabled ? 1 : 0.5
    function stepTo(requested) {
        if (!isFinite(requested)) return;
        var target = Math.max(control.from, Math.min(control.to, Math.round(requested)));
        var previous = control.value;
        if (target === previous) return;
        // One native step preserves the external value binding without doing
        // hundreds of intermediate UI updates for a typed or scrubbed jump.
        // Both module instances use a constant stepSize, restored immediately.
        var normalStep = control.stepSize;
        control.stepSize = Math.abs(target - previous);
        if (target > previous) control.increase();
        else control.decrease();
        control.stepSize = normalStep;
        if (control.value !== previous) control.valueModified();
    }
    background: Rectangle { color: "#171717"; radius: 3; border.color: "#111111" }
    validator: IntValidator { bottom: control.from; top: control.to }
    contentItem: TextInput {
        id: number
        text: control.textFromValue(control.value, control.locale)
        font: control.font; color: "#ebebeb"; selectionColor: "#ff9d00"; selectedTextColor: "#121212"
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        readOnly: !control.typing; inputMethodHints: Qt.ImhDigitsOnly
        validator: control.validator; clip: true
        onAccepted: { control.stepTo(Number(text)); control.typing = false; focus = false; }
        onActiveFocusChanged: { if (!activeFocus) control.typing = false; }
        MouseArea {
            anchors.fill: parent; enabled: !control.typing; preventStealing: true
            property real initialY: 0
            property int initialValue: 0
            onPressed: { initialY = mouse.y; initialValue = control.value; }
            onPositionChanged: { if (pressed) control.stepTo(initialValue + Math.round((initialY - mouse.y) / 3) * control.stepSize); }
            onDoubleClicked: { control.typing = true; number.forceActiveFocus(); number.selectAll(); }
        }
    }
    down.indicator: Rectangle {
        x: 0; y: 0; width: 60; height: control.height; radius: 3
        color: control.down.pressed ? "#ff9d00" : "#323232"
        Text { anchors.centerIn: parent; text: "−"; font.family: "Inter"; font.pixelSize: 30; color: control.down.pressed ? "#121212" : "#ebebeb" }
    }
    up.indicator: Rectangle {
        x: control.width - width; y: 0; width: 60; height: control.height; radius: 3
        color: control.up.pressed ? "#ff9d00" : "#323232"
        Text { anchors.centerIn: parent; text: "+"; font.family: "Inter"; font.pixelSize: 30; color: control.up.pressed ? "#121212" : "#ebebeb" }
    }
}

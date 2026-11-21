import QtQuick 2.11

Item {
    id: panel
    width: 1280; height: 720
    property string effect_id: ""
    property var backend
    property bool malaFullPanel: true
    property bool broadcastsRequested: false

    function returnToPatch() {
        if (patch_single.in_spotlight) {
            patchStack.pop();
            if (patchStack.currentItem === patch_single) {
                patch_single.in_spotlight = false;
                patch_single.currentMode = 0;
                patch_single.selected_effect = null;
                patch_single.current_help_text = qsTr("Select a module");
            }
        } else if (patch_single.selected_effect) {
            patch_single.selected_effect.back_action();
        }
    }
    Component.onCompleted: {
        if (effect_id) {
            knobs.set_broadcast(effect_id, true);
            broadcastsRequested = true;
        }
    }
    Component.onDestruction: {
        if (broadcastsRequested) knobs.set_broadcast(effect_id, false);
    }
    Loader {
        objectName: "view_loader"
        anchors.fill: parent
        sourceComponent: liveView
    }
    function toggleBypass() {
        if (currentEffects[panel.effect_id])
            knobs.set_bypass(panel.effect_id, !currentEffects[panel.effect_id]["enabled"].value);
    }
    Component {
        id: liveView
        LiveEditor {
            bridge: panel.backend
            moduleBypassed: currentEffects[panel.effect_id] ? !(currentEffects[panel.effect_id]["enabled"].value > 0) : false
            onBackRequested: panel.returnToPatch()
            onBypassRequested: panel.toggleBypass()
        }
    }


}

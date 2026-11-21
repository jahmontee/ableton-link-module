import QtQuick 2.11

Item {
    id: window
    objectName: "link_window_live"
    width: 1280; height: 720
    property var bridge
    property bool embedded: false
    property bool networkReady: bridge ? bridge.networkInstalled === true : false
    property bool moduleBypassed: false
    property bool helpOpen: false
    property var status: bridge ? bridge.status : ({})
    property string interfaceFont: regularFont.name
    signal backRequested()
    signal bypassRequested()
    FontLoader { id: regularFont; objectName: "inter_regular_font"; source: "fonts/Inter-400.ttf" }
    FontLoader { id: mediumFont; objectName: "inter_medium_font"; source: "fonts/Inter-500.ttf" }
    FontLoader { id: semiboldFont; objectName: "inter_semibold_font"; source: "fonts/Inter-600.ttf" }
    FontLoader { id: boldFont; objectName: "inter_bold_font"; source: "fonts/Inter-700.ttf" }

    Rectangle { anchors.fill: parent; color: "#141414" }

    Rectangle {
        objectName: "connection_card"
        x: 20; y: 20; width: 1240; height: 140; radius: 3
        color: "#1e1e1e"; border.color: "#333333"; border.width: 1
    }
    Text {
        id: syncTitle; objectName: "sync_title"
        x: 46; y: 57; text: "Poly / Link"
        font.family: window.interfaceFont; font.pixelSize: 29; font.bold: true; color: "#ebebeb"
    }
    Text {
        objectName: "sync_subtitle"; x: 46; y: 109; width: 214; height: 28
        text: "Ableton Link"
        font.family: window.interfaceFont; font.pixelSize: 20; color: "#9b9b9b"
    }
    Text {
        objectName: "sync_version"; x: 260; y: 63; width: 172; height: 26
        text: window.bridge && window.bridge.moduleVersion ? "v" + window.bridge.moduleVersion : ""
        textFormat: Text.PlainText
        font.family: window.interfaceFont; font.pixelSize: 15; font.weight: Font.Medium; color: "#9b9b9b"
        verticalAlignment: Text.AlignVCenter
    }

    Rectangle { x: 454; y: 53; width: 1; height: 75; color: "#333333" }
    Text {
        objectName: "sync_connection_ip"; x: 498; y: 43; width: 300; height: 26
        text: "Connection: " + (window.status.ip || "—")
        font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b"; elide: Text.ElideRight
    }
    LiveChoice {
        objectName: "sync_connection"; x: 498; y: 74; width: 300; height: 64
        font.family: window.interfaceFont; font.pixelSize: 22
        model: ["Ethernet", "Wi-Fi"]; bottomClearance: 96
        currentIndex: window.status.connection === "ethernet" ? 0 : 1
        enabled: window.networkReady && !window.status.busy
        onActivated: window.bridge.selectConnection(currentIndex === 0 ? "ethernet" : "wifi")
    }
    Rectangle { x: 864; y: 73; width: 12; height: 12; radius: 6; color: window.status.ready ? "#38d9a9" : "#ffbd54" }
    Text {
        objectName: "sync_helper_status"; x: 890; y: 43; width: 344; height: 60
        text: !window.networkReady ? "Network Connection required" : (window.status.connectionStatus || "Checking connection…")
        font.family: window.interfaceFont; font.pixelSize: 20; font.bold: true; color: "#ebebeb"; wrapMode: Text.WordWrap
    }
    Text {
        objectName: "sync_peers"; x: 890; y: 112; width: 210; height: 30
        text: !window.networkReady || !window.status.ready ? "Peers unavailable" : (window.status.peers || 0) + (window.status.peers === 1 ? " connected peer" : " connected peers")
        font.family: window.interfaceFont; font.pixelSize: 22; color: "#9b9b9b"; elide: Text.ElideRight
    }
    LiveButton {
        objectName: "sync_retry"; x: 1110; y: 104; width: 124; height: 48
        text: "Retry"; font.family: window.interfaceFont; font.pixelSize: 22
        visible: window.status.canRetry === true; enabled: window.networkReady && !window.status.busy
        onClicked: window.bridge.retryConnection()
    }
    Text {
        objectName: "link_error"; x: 46; y: 160; width: 1188; height: 20
        text: window.bridge ? window.bridge.error : ""; visible: text.length > 0
        font.family: window.interfaceFont; font.pixelSize: 16; color: "#ffbd54"; elide: Text.ElideRight
    }

    Rectangle {
        objectName: "tempo_card"
        x: 20; y: 180; width: 1240; height: 272; radius: 3
        color: "#1e1e1e"; border.color: "#333333"; border.width: 1
    }
    Text { x: 46; y: 192; text: "Tempo & Clock"; font.family: window.interfaceFont; font.pixelSize: 22; font.bold: true; color: "#ebebeb" }
    Text { x: 46; y: 226; text: "Current BPM"; font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b" }
    Text { x: 270; y: 226; text: "Set BPM"; font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b" }
    Text { x: 700; y: 226; text: "Clock pulse rate"; font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b" }
    Text { x: 978; y: 226; text: "Launch every"; font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b" }
    Text {
        objectName: "bpm_value"; x: 44; y: 249; width: 200; height: 70
        text: window.networkReady && window.status.ready ? Number(window.status.bpm || 120).toFixed(2) : "—"
        font.family: window.interfaceFont; font.pixelSize: 50; font.bold: true; color: "#ff9d00"; elide: Text.ElideRight
    }
    LiveTempo {
        id: tempo; objectName: "tempo_input"; x: 270; y: 253; width: 224; height: 64
        from: 20; to: 999; value: 120; enabled: window.networkReady
        font.family: window.interfaceFont; font.pixelSize: 29
    }
    LiveButton {
        objectName: "tempo_apply"; x: 510; y: 253; width: 128; height: 64; text: "APPLY"
        font.family: window.interfaceFont; font.pixelSize: 22
        enabled: window.networkReady; onClicked: window.bridge.change("sync", "tempo_request", tempo.value)
    }
    Rectangle { x: 669; y: 239; width: 1; height: 78; color: "#333333" }
    LiveChoice {
        objectName: "clock_choice"; x: 700; y: 253; width: 258; height: 64
        model: ["1 pulse / beat", "2 pulses / beat", "4 pulses / beat", "24 pulses / beat"]
        currentIndex: [1,2,4,24].indexOf(window.status.ppq || 1)
        displayText: currentIndex >= 0 ? currentText : (window.status.ppq + " pulses / beat")
        font.family: window.interfaceFont; font.pixelSize: 21; bottomClearance: 96
        enabled: window.networkReady; onActivated: window.bridge.change("sync", "ppq", [1,2,4,24][currentIndex])
    }
    LiveChoice {
        id: launchChoice; objectName: "quantum_choice"; x: 978; y: 253; width: 256; height: 64
        model: ["1 beat", "2 beats", "4 beats", "8 beats", "16 beats"]
        currentIndex: [1,2,4,8,16].indexOf(window.status.launchQuantum || 4)
        displayText: currentIndex >= 0 ? currentText : (window.status.launchQuantum + " beats")
        font.family: window.interfaceFont; font.pixelSize: 21; bottomClearance: 96
        enabled: window.networkReady; onActivated: window.bridge.change("sync", "quantum", [1,2,4,8,16][currentIndex])
    }
    Rectangle { x: 46; y: 343; width: 1188; height: 1; color: "#333333" }
    Text { x: 46; y: 381; text: "Link Offset (ms)"; font.family: window.interfaceFont; font.pixelSize: 21; font.bold: true; color: "#ebebeb" }
    LiveTempo {
        objectName: "sync_offset"; x: 270; y: 365; width: 224; height: 64
        from: -500; to: 500; stepSize: 1; enabled: window.networkReady
        value: Math.round(window.status.offsetMs || 0)
        font.family: window.interfaceFont; font.pixelSize: 29
        textFromValue: function(value, locale) { return (value > 0 ? "+" : "") + value; }
        onValueModified: window.bridge.change("sync", "offset_ms", value)
    }
    LiveButton {
        objectName: "sync_offset_zero"; x: 510; y: 365; width: 128; height: 64; text: "ZERO"
        font.family: window.interfaceFont; font.pixelSize: 22
        enabled: window.networkReady; onClicked: window.bridge.change("sync", "offset_ms", 0)
    }
    Text { x: 700; y: 384; text: "− earlier    /    + later"; font.family: window.interfaceFont; font.pixelSize: 22; color: "#9b9b9b" }

    Text {
        objectName: "clock_width_label"; x: launchChoice.x; y: 350; width: launchChoice.width; height: 26
        text: "Clock pulse width"
        font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b"
    }
    LiveChoice {
        objectName: "clock_width_choice"; x: launchChoice.x; y: 381; width: launchChoice.width; height: 58
        model: ["1 ms", "5 ms", "10 ms"]
        currentIndex: Math.max(0, [1,5,10].indexOf(window.status.clockWidthMs || 1))
        font.family: window.interfaceFont; font.pixelSize: 21; bottomClearance: 96
        enabled: window.networkReady
        onActivated: window.bridge.change("sync", "clock_width_ms", [1,5,10][currentIndex])
    }

    Rectangle {
        objectName: "playback_card"
        x: 20; y: 472; width: 1240; height: 132; radius: 3
        color: "#1e1e1e"; border.color: "#333333"; border.width: 1
    }
    Text { x: 46; y: 484; text: "Link & Playback"; font.family: window.interfaceFont; font.pixelSize: 22; font.bold: true; color: "#ebebeb" }
    Text { x: 978; y: 490; text: "Playback status"; font.family: window.interfaceFont; font.pixelSize: 18; color: "#9b9b9b" }
    LiveButton {
        objectName: "link_enable"; x: 46; y: 520; width: 184; height: 64; text: "LINK"
        font.family: window.interfaceFont; font.pixelSize: 22; checkable: true; checked: window.status.enabled > 0
        enabled: window.networkReady; onClicked: window.bridge.change("sync", "enabled", checked ? 1 : 0)
    }
    LiveButton {
        objectName: "start_button"; x: 254; y: 520; width: 128; height: 64; text: "START"
        font.family: window.interfaceFont; font.pixelSize: 22; enabled: window.networkReady; onClicked: window.bridge.transport(true)
    }
    LiveButton {
        objectName: "stop_button"; x: 398; y: 520; width: 128; height: 64; text: "STOP"
        font.family: window.interfaceFont; font.pixelSize: 22; enabled: window.networkReady; onClicked: window.bridge.transport(false)
    }
    LiveButton {
        objectName: "start_stop_sync"; x: 550; y: 520; width: 380; height: 64; text: "SHARE START / STOP"
        font.family: window.interfaceFont; font.pixelSize: 22; checkable: true; checked: window.status.startStop > 0
        enabled: window.networkReady; onClicked: window.bridge.change("sync", "start_stop_sync", checked ? 1 : 0)
    }
    Rectangle {
        x: 978; y: 520; width: 256; height: 64; radius: 3; color: "#171717"; border.color: "#111111"
        Rectangle { x: 21; y: 27; width: 10; height: 10; radius: 5; color: window.status.running ? "#38d9a9" : window.status.playing ? "#ffbd54" : "#6e6e6e" }
        Text {
            objectName: "playback_status"; x: 48; y: 0; height: 64; width: 196
            text: !window.networkReady || !window.status.ready ? "UNAVAILABLE" : window.status.running ? "PLAYING" : window.status.playing ? "QUEUED" : "STOPPED"
            font.family: window.interfaceFont; font.pixelSize: 21; font.bold: true; color: "#ebebeb"; verticalAlignment: Text.AlignVCenter
        }
    }

    Rectangle { x: 0; y: 624; width: parent.width; height: 1; color: "#333333" }
    LiveButton {
        objectName: "sync_back"; x: 31; y: 635; width: 120; height: 70; text: "BACK"
        font.family: window.interfaceFont; font.pixelSize: 22; onClicked: window.backRequested()
    }
    LiveButton {
        objectName: "sync_module_title"; anchors.horizontalCenter: parent.horizontalCenter; y: 635; width: 250; height: 70; text: "ABLETON LINK"
        font.family: window.interfaceFont; font.pixelSize: 21
        background: Rectangle { color: "#262626"; radius: 3; border.color: "#3a3a3a" }
        contentItem: Item {
            Rectangle {
                x: 16; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; radius: 10
                color: "transparent"; border.color: "#9b9b9b"
                Text { anchors.centerIn: parent; text: "i"; font.family: window.interfaceFont; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#ebebeb" }
            }
            Text { objectName: "device_title_text"; x: 42; width: parent.width - 56; height: parent.height; text: "ABLETON LINK"; font.family: window.interfaceFont; font.pixelSize: 21; font.weight: Font.Bold; color: "#ebebeb"; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }
        Accessible.name: "About Ableton Link"
        onClicked: window.helpOpen = true
    }

    LiveButton {
        objectName: "sync_bypass"
        anchors.right: parent.right; anchors.rightMargin: 31
        y: 635; width: 222; height: 70; text: "BYPASS"
        font.family: window.interfaceFont; font.pixelSize: 22
        checkable: true; checked: window.moduleBypassed
        onClicked: window.bypassRequested()
    }

    Item {
        objectName: "sync_help_overlay"; anchors.fill: parent; z: 10; visible: window.helpOpen
        // This local help view never changes playback, Link enable or bypass.
        Rectangle { anchors.fill: parent; color: "#cc10191e" }
        MouseArea { anchors.fill: parent }
        Rectangle {
            x: 100; y: 60; width: 1080; height: 600; radius: 3
            color: "#1e1e1e"; border.color: "#333333"; border.width: 1
            Text {
                x: 32; y: 24; width: 1016; height: 46; text: "About Ableton Link"
                font.family: window.interfaceFont; font.pixelSize: 34; font.bold: true; color: "#ebebeb"
            }
            Text {
                objectName: "sync_help_version"; x: 32; y: 76; width: 1016; height: 24
                text: "Poly / Link  ·  " + (window.bridge && window.bridge.moduleVersion ? "v" + window.bridge.moduleVersion : "")
                font.family: window.interfaceFont; font.pixelSize: 16; color: "#9b9b9b"
            }
            Text {
                objectName: "sync_help_body"; x: 32; y: 112; width: 1016; height: 376
                font.family: window.interfaceFont; font.pixelSize: 22; color: "#ebebeb"
                wrapMode: Text.WordWrap; textFormat: Text.PlainText; lineHeight: 1.12
                text: "Ableton Link shares tempo and phase with compatible apps on the same network.\n\n"
                    + "Network Connection is required. Configure your adapter there, select Ethernet or Wi-Fi here, then turn Link ON. Enable Link in your other app.\n\n"
                    + "Clock width: 1, 5 or 10 ms, limited to half a clock period at fast rates. Run stays high while playing; Reset pulses at the start. Launch every sets the start boundary. Share Start / Stop shares transport.\n\n"
                    + "Offset moves Hector earlier (−) or later (+). Zero clears it. Save your preset to keep width and offset. Link Audio uses separate modules."
            }
            LiveButton {
                objectName: "sync_help_close"; x: 888; y: 508; width: 160; height: 64; text: "Close"
                font.family: window.interfaceFont; font.pixelSize: 22
                onClicked: window.helpOpen = false
            }
        }
    }
}

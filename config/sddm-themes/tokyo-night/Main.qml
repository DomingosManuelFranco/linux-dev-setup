import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Item {
    id: root

    // ====== TOKYO NIGHT PALETTE ======
    QtObject {
        id: pal
        property color background:    "#1a1b26"
        property color surface:       "#24283b"
        property color surfaceAlt:    "#292e42"
        property color overlay:       "#1f2335"
        property color text:          "#c0caf5"
        property color textDim:       "#565f89"
        property color textFaint:     "#414868"
        property color accent:        "#7aa2f7"
        property color accentAlt:     "#bb9af7"
        property color accentGreen:   "#9ece6a"
        property color accentRed:     "#f7768e"
        property color accentOrange:  "#ff9e64"
        property color accentYellow:  "#e0af68"
        property color white:         "#ffffff"
    }

    // ====== STATE ======
    property string authState:          "idle"
    property bool   showPw:             false
    property bool   capsOn:             false
    property int    currentSession:     0
    property string currentSessionName: "niri"
    property string currentUser:        ""
    property var    powerConfirm:       null
    property int    batteryLevel:       -1
    property bool   batteryCharging:    false

    function _readFile(path) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path, false)
        try { xhr.send() } catch(e) { return "" }
        return (xhr.status === 200 || xhr.status === 0) ? xhr.responseText.trim() : ""
    }

    function _updateBattery() {
        var paths = ["/BAT0", "/BAT1", "/BAT2"]
        for (var i = 0; i < paths.length; i++) {
            var base = "/sys/class/power_supply" + paths[i]
            var cap = _readFile(base + "/capacity")
            if (cap !== "") {
                batteryLevel    = parseInt(cap)
                batteryCharging = (_readFile(base + "/status") === "Charging")
                return
            }
        }
        batteryLevel = -1
    }

    Component.onCompleted: {
        if (sessionModel.lastIndex >= 0) currentSession = sessionModel.lastIndex
        currentSessionName = sessionModel.count > 0
            ? (sessionModel.data(sessionModel.index(currentSession, 0), Qt.DisplayRole) || "niri")
            : "niri"

        if (userModel.lastUser && userModel.lastUser !== "")
            currentUser = userModel.lastUser
        else {
            for (var i = 0; i < userModel.count; i++) {
                var n = userModel.data(userModel.index(i, 0), Qt.DisplayRole)
                if (n && n !== "") { currentUser = n; break }
            }
        }
        if (!currentUser || currentUser === "") currentUser = "user"
        _updateBattery()
    }

    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: _updateBattery()
    }

    property string greeting: {
        var h = new Date().getHours()
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    Timer {
        id: clockTimer; interval: 1000; running: true; repeat: true
        property var now: new Date()
        onTriggered: now = new Date()
    }

    Timer {
        id: errorTimer; interval: 620
        onTriggered: { authState = "idle"; passwordField.text = "" }
    }

    Connections {
        target: sddm
        function onLoginFailed()    { authState = "error"; errorTimer.restart() }
        function onLoginSucceeded() { authState = "success" }
    }

    function doLogin() {
        if (authState === "checking" || authState === "success") return
        if (!passwordField.text) { authState = "error"; errorTimer.restart(); return }
        authState = "checking"
        sddm.login(currentUser, passwordField.text, currentSession)
    }

    // ====== BACKGROUND ======
    Image {
        id: bgImage
        anchors.fill: parent
        source: (config.background && config.background !== "") ? "file://" + config.background : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.07, 0.12, 0.65) }
            GradientStop { position: 0.5; color: Qt.rgba(0.07, 0.07, 0.12, 0.45) }
            GradientStop { position: 1.0; color: Qt.rgba(0.07, 0.07, 0.12, 0.75) }
        }
    }

    // ====== TOP-RIGHT STATUS PILLS ======
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 24
        anchors.rightMargin: 26
        spacing: 8
        z: 10

        Rectangle {
            height: 34; radius: 17
            color: Qt.rgba(0.14, 0.16, 0.23, 0.80)
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
            width: hostPill.implicitWidth + 24
            Row {
                id: hostPill; anchors.centerIn: parent; spacing: 6
                Text {
                    text: "\u2302"
                    font.pixelSize: 16
                    color: pal.accentAlt
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: sddm.hostName || "localhost"
                    font.family: "Noto Sans"; font.pixelSize: 14; font.weight: Font.Bold
                    color: pal.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            visible: batteryLevel >= 0
            height: 34; radius: 17
            color: Qt.rgba(0.14, 0.16, 0.23, 0.80)
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
            width: batPill.implicitWidth + 24
            Row {
                id: batPill; anchors.centerIn: parent; spacing: 6
                Text {
                    text: batteryCharging ? "\u26A1" : "\u2B1B"
                    font.pixelSize: 14
                    color: batteryLevel <= 20 ? pal.accentRed : pal.accentGreen
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: batteryLevel + "%"
                    font.family: "Noto Sans"; font.pixelSize: 14; font.weight: Font.Bold
                    color: batteryLevel <= 20 ? pal.accentRed : pal.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ====== SPLIT LAYOUT ======
    Item {
        anchors.fill: parent
        z: 5

        // ---- LEFT PANE ----
        Item {
            width: parent.width * 0.55
            height: parent.height

            Column {
                anchors.centerIn: parent
                spacing: 22

                // Greeting
                Text {
                    text: greeting
                    color: pal.accentAlt
                    font.family: "Noto Sans"; font.pixelSize: 18
                    font.weight: Font.Normal
                }

                // Clock
                Column {
                    spacing: 2
                    Row {
                        spacing: 4
                        Text {
                            color: pal.text
                            font.family: "Noto Sans"; font.pixelSize: 140
                            font.weight: Font.Light
                            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.50)
                            text: {
                                var h = clockTimer.now.getHours()
                                return String(h).padStart(2, "0")
                            }
                        }
                        Text {
                            color: Qt.rgba(0.75, 0.79, 0.96, 0.40)
                            font.family: "Noto Sans"; font.pixelSize: 140
                            font.weight: Font.Light
                            text: ":"
                            SequentialAnimation on opacity {
                                running: true; loops: Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 1000 }
                                NumberAnimation { to: 1.0; duration: 1000 }
                            }
                        }
                        Text {
                            color: pal.text
                            font.family: "Noto Sans"; font.pixelSize: 140
                            font.weight: Font.Light
                            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.50)
                            text: String(clockTimer.now.getMinutes()).padStart(2, "0")
                        }
                    }
                    Text {
                        text: clockTimer.now.toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d")
                        color: pal.textDim
                        font.family: "Noto Sans"; font.pixelSize: 22; font.weight: Font.Bold
                    }
                }
            }
        }

        // ---- RIGHT PANE (semi-transparent overlay) ----
        Item {
            x: parent.width * 0.55
            width: parent.width * 0.45
            height: parent.height

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.10, 0.11, 0.15, 0.55)
            }

            Rectangle {
                anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                width: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            // ---- LOGIN FORM ----
            Column {
                anchors.centerIn: parent
                spacing: 20
                width: Math.min(380, Math.round(parent.width * 0.84))

                // Avatar circle
                Rectangle {
                    width: 100; height: 100; radius: 50
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "transparent"
                    border.color: Qt.rgba(0.48, 0.64, 0.97, 0.45)
                    border.width: 2

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: pal.accent }
                        GradientStop { position: 1.0; color: pal.accentAlt }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: currentUser ? currentUser.charAt(0).toUpperCase() : "U"
                        color: pal.background
                        font.family: "Noto Sans"; font.pixelSize: 42; font.weight: Font.Bold
                    }
                }

                // Welcome text
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: greeting + ","
                        color: pal.textDim
                        font.family: "Noto Sans"; font.pixelSize: 15
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: currentUser
                        color: pal.text
                        font.family: "Noto Sans"; font.pixelSize: 26; font.weight: Font.SemiBold
                    }
                }

                // Password field
                Rectangle {
                    id: pwWrap
                    width: parent.width; height: 56; radius: 28
                    color: Qt.rgba(0.16, 0.18, 0.26, 0.85)
                    border.width: 2
                    border.color: authState === "error"   ? pal.accentRed
                                : authState === "success" ? pal.accentGreen
                                : passwordField.activeFocus
                                    ? pal.accent
                                    : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    SequentialAnimation {
                        running: authState === "error"
                        NumberAnimation { target: pwWrap; property: "x"; from: -6; to: 6; duration: 50 }
                        NumberAnimation { target: pwWrap; property: "x"; from: 6; to: -6; duration: 50 }
                        NumberAnimation { target: pwWrap; property: "x"; from: -6; to: 0; duration: 50 }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 8
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: authState === "success" ? "\u2714" : "\uD83D\uDD12"
                            font.pixelSize: 18
                            color: authState === "error" ? pal.accentRed
                                 : authState === "success" ? pal.accentGreen
                                 : passwordField.activeFocus ? pal.accent
                                 : pal.textFaint
                        }

                        TextInput {
                            id: passwordField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 120
                            color: pal.text
                            font.family: "Noto Sans"; font.pixelSize: 16
                            echoMode: showPw ? TextInput.Normal : TextInput.Password
                            enabled: authState !== "checking" && authState !== "success"
                            focus: true
                            Keys.onReturnPressed: doLogin()
                            Keys.onEnterPressed: doLogin()
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: passwordField.text === ""
                            text: "Password"
                            color: pal.textFaint
                            font.family: "Noto Sans"; font.pixelSize: 16
                            x: 54
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: showPw ? "\uD83D\uDC41" : "\u25C9"
                            font.pixelSize: 16
                            color: pal.textDim
                            MouseArea {
                                anchors.fill: parent
                                onClicked: showPw = !showPw
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42; height: 42; radius: 21
                            color: authState === "success" ? pal.accentGreen : pal.accent

                            Text {
                                anchors.centerIn: parent
                                visible: authState !== "checking"
                                text: authState === "success" ? "\u2714" : "\u2192"
                                font.pixelSize: 18; font.weight: Font.Bold
                                color: pal.background
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: authState === "checking"
                                width: 20; height: 20; radius: 10
                                color: "transparent"
                                border.width: 2; border.color: Qt.rgba(0.10, 0.11, 0.15, 0.30)
                                Rectangle {
                                    width: 2; height: 8; x: 9; y: 1
                                    color: pal.background
                                    transformOrigin: Item.Bottom
                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 700
                                        loops: Animation.Infinite; running: authState === "checking"
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: authState !== "checking"
                                onClicked: doLogin()
                            }
                        }
                    }
                }

                // Caps lock
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6; visible: capsOn
                    Text { text: "\u26A0"; font.pixelSize: 14; color: pal.accentOrange }
                    Text {
                        text: "Caps Lock is on"
                        color: pal.accentOrange
                        font.family: "Noto Sans"; font.pixelSize: 13; font.weight: Font.Medium
                    }
                }

                // Error message
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: authState === "error"
                    text: "Wrong password"
                    color: pal.accentRed
                    font.family: "Noto Sans"; font.pixelSize: 13
                }
            }
        }
    }

    // ====== BOTTOM BAR ======
    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 28; anchors.rightMargin: 28; anchors.bottomMargin: 24
        height: 46; z: 10

        // Session picker
        Rectangle {
            id: sessionBtn
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            height: 38; radius: 19
            width: sessRow.implicitWidth + 24
            color: sArea.containsMouse
                ? Qt.rgba(0.18, 0.20, 0.29, 0.85)
                : Qt.rgba(0.14, 0.16, 0.23, 0.70)
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            Row {
                id: sessRow; anchors.centerIn: parent; spacing: 8
                Text { text: "\u25A0"; font.pixelSize: 8; color: pal.accent; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: currentSessionName
                    font.family: "Noto Sans"; font.pixelSize: 14; font.weight: Font.Medium
                    color: pal.text; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "\u25B2"; font.pixelSize: 10
                    color: pal.textDim; anchors.verticalCenter: parent.verticalCenter
                    rotation: sessionMenu.visible ? 0 : 180
                    Behavior on rotation { NumberAnimation { duration: 200 } }
                }
            }
            MouseArea {
                id: sArea; anchors.fill: parent; hoverEnabled: true
                onClicked: sessionMenu.visible = !sessionMenu.visible
            }
        }

        // Power buttons
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 44; height: 44; radius: 12
                color: pSus.containsMouse
                    ? Qt.rgba(0.18, 0.20, 0.29, 0.85)
                    : Qt.rgba(0.14, 0.16, 0.23, 0.70)
                border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "\uD83C\uDF19"; font.pixelSize: 20
                    opacity: pSus.containsMouse ? 1.0 : 0.6
                }
                MouseArea {
                    id: pSus; anchors.fill: parent; hoverEnabled: true
                    onClicked: powerConfirm = { label: "Suspend", action: "suspend", danger: false }
                }
            }

            Rectangle {
                width: 44; height: 44; radius: 12
                color: pReb.containsMouse
                    ? Qt.rgba(0.18, 0.20, 0.29, 0.85)
                    : Qt.rgba(0.14, 0.16, 0.23, 0.70)
                border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "\u21BA"; font.pixelSize: 22
                    opacity: pReb.containsMouse ? 1.0 : 0.6
                    color: pal.accentAlt
                }
                MouseArea {
                    id: pReb; anchors.fill: parent; hoverEnabled: true
                    onClicked: powerConfirm = { label: "Restart", action: "reboot", danger: false }
                }
            }

            Rectangle {
                width: 44; height: 44; radius: 12
                color: pShut.containsMouse
                    ? Qt.rgba(0.97, 0.46, 0.54, 0.22)
                    : Qt.rgba(0.14, 0.16, 0.23, 0.70)
                border.color: pShut.containsMouse
                    ? Qt.rgba(0.97, 0.46, 0.54, 0.40)
                    : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "\u23FB"; font.pixelSize: 20
                    color: pShut.containsMouse ? pal.accentRed : pal.textDim
                }
                MouseArea {
                    id: pShut; anchors.fill: parent; hoverEnabled: true
                    onClicked: powerConfirm = { label: "Shut Down", action: "shutdown", danger: true }
                }
            }
        }
    }

    // ====== SESSION DROPDOWN ======
    Rectangle {
        id: sessionMenu
        visible: false; z: 20
        x: 28
        y: root.height - 24 - 46 - height - 10
        width: 220; radius: 14
        height: Math.min(sessionModel.count * 42 + 14, 210)
        color: Qt.rgba(0.13, 0.15, 0.21, 0.96)
        border.color: Qt.rgba(1, 1, 1, 0.10); border.width: 1
        clip: true

        ListView {
            anchors.fill: parent; anchors.margins: 7
            model: sessionModel; spacing: 2
            delegate: Rectangle {
                width: ListView.view.width; height: 40; radius: 8
                color: index === currentSession
                    ? Qt.rgba(0.48, 0.64, 0.97, 0.16)
                    : (sessItemMa.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                Text {
                    anchors.fill: parent; anchors.leftMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    text: (model.name || model.display || "")
                    font.family: "Noto Sans"; font.pixelSize: 14; font.weight: Font.Medium
                    color: index === currentSession ? pal.accent : pal.textDim
                }
                MouseArea {
                    id: sessItemMa; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        currentSession = index
                        currentSessionName = model.name || model.display || sessionModel.data(sessionModel.index(index, 0), Qt.DisplayRole) || "niri"
                        sessionMenu.visible = false
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent; z: 19
        visible: sessionMenu.visible
        onClicked: sessionMenu.visible = false
    }

    // ====== POWER CONFIRM OVERLAY ======
    Rectangle {
        anchors.fill: parent; z: 25
        visible: powerConfirm !== null
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea { anchors.fill: parent; onClicked: powerConfirm = null }

        Rectangle {
            anchors.centerIn: parent
            width: 340; radius: 20
            height: confirmCol.implicitHeight + 50
            color: Qt.rgba(0.13, 0.15, 0.21, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            MouseArea { anchors.fill: parent }

            Column {
                id: confirmCol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 14

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64; radius: 32
                    color: powerConfirm && powerConfirm.danger
                        ? Qt.rgba(0.97, 0.46, 0.54, 0.18)
                        : Qt.rgba(0.48, 0.64, 0.97, 0.18)
                    Text {
                        anchors.centerIn: parent
                        text: powerConfirm && powerConfirm.danger ? "\u23FB" : "\u21BA"
                        font.pixelSize: 32
                        color: powerConfirm && powerConfirm.danger ? pal.accentRed : pal.accent
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: powerConfirm ? (powerConfirm.label + "?") : ""
                    color: pal.text
                    font.family: "Noto Sans"; font.pixelSize: 20; font.weight: Font.SemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!powerConfirm) return ""
                        if (powerConfirm.action === "suspend") return "The system will sleep and resume later."
                        if (powerConfirm.action === "reboot") return "All applications will close."
                        return "All applications will close."
                    }
                    color: pal.textDim
                    font.family: "Noto Sans"; font.pixelSize: 14
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    topPadding: 6

                    Rectangle {
                        width: 120; height: 44; radius: 22
                        color: cancelMa2.containsMouse
                            ? Qt.rgba(0.22, 0.24, 0.35, 0.80)
                            : Qt.rgba(0.16, 0.18, 0.26, 0.60)
                        border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                        Text {
                            anchors.centerIn: parent; text: "Cancel"
                            color: pal.text; font.family: "Noto Sans"
                            font.pixelSize: 14; font.weight: Font.Medium
                        }
                        MouseArea {
                            id: cancelMa2; anchors.fill: parent; hoverEnabled: true
                            onClicked: powerConfirm = null
                        }
                    }

                    Rectangle {
                        width: 120; height: 44; radius: 22
                        color: powerConfirm && powerConfirm.danger ? pal.accentRed : pal.accent
                        Text {
                            anchors.centerIn: parent
                            text: powerConfirm ? powerConfirm.label : ""
                            color: pal.background; font.family: "Noto Sans"
                            font.pixelSize: 14; font.weight: Font.Bold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var a = powerConfirm ? powerConfirm.action : ""
                                powerConfirm = null
                                if (a === "suspend") sddm.suspend()
                                else if (a === "reboot") sddm.reboot()
                                else if (a === "shutdown") sddm.powerOff()
                            }
                        }
                    }
                }
            }
        }
    }

    // Force cursor shape
    MouseArea {
        anchors.fill: parent; z: 9999
        acceptedButtons: Qt.NoButton; hoverEnabled: true
        cursorShape: Qt.ArrowCursor
    }
}

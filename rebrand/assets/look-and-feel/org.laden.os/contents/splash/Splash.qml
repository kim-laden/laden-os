import QtQuick 2.15

Rectangle {
    id: root
    color: "#050807"
    property int stage

    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/laden/laden-os-art-v5-1920x1080.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.62
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#99050807" }
            GradientStop { position: 1.0; color: "#66050807" }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.40
        text: "LADEN"
        color: "#f4fff9"
        font.pixelSize: 76
        font.letterSpacing: 16
        font.weight: Font.Light
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.40 + 92
        text: "Let's do it!"
        color: "#39ffb0"
        font.pixelSize: 28
        font.weight: Font.Medium
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        width: Math.max(24, parent.width * 0.18 * Math.min(stage, 6) / 6)
        height: 3
        radius: 1
        color: "#39ffb0"
    }
}

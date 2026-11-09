import QtQuick 2.0

Rectangle {
    color: "#071210"
    Image {
        anchors.fill: parent
        source: "welcome.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.35
    }
    Text {
        anchors.centerIn: parent
        text: "Let's do it!"
        color: "#39ffb0"
        font.pixelSize: 36
    }
}

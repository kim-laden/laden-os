/* SPDX-License-Identifier: GPL-3.0-or-later
 * Laden OS installer slideshow (Calamares slideshow API 2). */
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        id: advance
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    component LadenSlide: Slide {
        property string heading
        property string body
        Rectangle {
            anchors.fill: parent
            color: "#050b09"
            Image {
                anchors.fill: parent
                source: "welcome.png"
                fillMode: Image.PreserveAspectCrop
                opacity: 0.30
            }
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.8
                spacing: 18
                Text {
                    width: parent.width
                    text: heading
                    color: "#39ffb0"
                    font.pixelSize: 30
                    font.bold: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: body
                    color: "#e9fff5"
                    font.pixelSize: 17
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    LadenSlide {
        heading: "Welcome to Laden OS"
        body: "A KDE Plasma desktop tuned for speed, based on CachyOS and Arch Linux. Sit back while your new system is set up."
    }
    LadenSlide {
        heading: "Laden Update keeps you current"
        body: "The tray applet tells you when updates are ready and walks you through them, including news and pacnew files."
    }
    LadenSlide {
        heading: "Your kernel, your scheduler"
        body: "Laden Kernel Manager and Laden Scheduler let you pick kernels and sched-ext CPU schedulers from a friendly window."
    }
    LadenSlide {
        heading: "Add an edition any time"
        body: "Gaming, Creator, Streaming and Pentest are meta-packages. Install one later with: sudo pacman -S laden-gaming"
    }
    LadenSlide {
        heading: "Let's do it!"
        body: "Thanks for choosing Laden OS."
    }

    function onActivate() { advance.restart() }
    function onLeave() { advance.stop() }
}

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Window 2.7
import "Base"
import "SidePane"

Item {
    id: mainUI

    Component.onCompleted: window.mainUI = mainUI

    property alias shortcuts: shortcuts
    property alias sidePane: sidePane
    property alias pageLoader: pageLoader
    property alias pressAnimation: pressAnimation

    SequentialAnimation {
        id: pressAnimation
        HNumberAnimation {
            target: mainUI; property: "scale"; from: 1.0; to: 0.9
        }
        HNumberAnimation {
            target: mainUI; property: "scale"; from: 0.9; to: 1.0
        }
    }

    property bool accountsPresent:
        (modelSources["Account"] || []).length > 0 ||
        py.startupAnyAccountsSaved


    Shortcuts { id: shortcuts }

    HImage {
        id: mainUIBackground
        visible: Boolean(Qt.resolvedUrl(source))
        fillMode: Image.PreserveAspectCrop
        source: theme.ui.image
        sourceSize.width: Screen.width
        sourceSize.height: Screen.height
        anchors.fill: parent
        asynchronous: false
    }

    Rectangle {
        id: mainUIGradient
        anchors.fill: parent
        scale: Math.max(
            2.25, Math.ceil(parent.parent.width / parent.parent.height)
        )
        rotation: theme.ui.gradientRotation
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.ui.gradientStart }
            GradientStop { position: 1.0; color: theme.ui.gradientEnd }
        }
    }


    HSplitView {
        id: uiSplitView
        anchors.fill: parent

        onAnyResizingChanged: if (anyResizing) {
            sidePane.manuallyResizing = true
        } else {
            sidePane.manuallyResizing = false
            sidePane.manuallyResized = true
            sidePane.manualWidth = sidePane.width
        }

        SidePane {
            id: sidePane

            // Initial width until user manually resizes
            width: implicitWidth
            Layout.minimumWidth: reduce ? 0 : theme.sidePane.collapsedWidth
            Layout.maximumWidth:
                window.width - theme.minimumSupportedWidthPlusSpacing

            Behavior on Layout.minimumWidth { HNumberAnimation {} }
        }

        HLoader {
            id: pageLoader
            property bool isWide: width > theme.contentIsWideAbove

            Component.onCompleted: {
                if (! py.startupAnyAccountsSaved) {
                    pageLoader.showPage("SignIn")
                    return
                }

                let page  = window.uiState.page
                let props = window.uiState.pageProperties

                if (page == "Chat/Chat.qml") {
                    pageLoader.showRoom(props.userId, props.roomId)
                } else {
                    pageLoader._show(page, props)
                }
            }

            function _show(componentUrl, properties={}) {
                pageLoader.setSource(componentUrl, properties)
            }

            function showPage(name, properties={}) {
                let path = "Pages/" + name + ".qml"
                _show(path, properties)

                window.uiState.page           = path
                window.uiState.pageProperties = properties
                window.uiStateChanged()
            }

            function showRoom(userId, roomId) {
                _show("Chat/Chat.qml", {userId, roomId})

                window.uiState.page           = "Chat/Chat.qml"
                window.uiState.pageProperties = {userId, roomId}
                window.uiStateChanged()
            }

            onStatusChanged: if (status == Loader.Ready) {
                item.forceActiveFocus()
                appearAnimation.start()
            }

            clip: appearAnimation.running
            XAnimator {
                id: appearAnimation
                target: pageLoader.item
                from: -300
                to: 0
                easing.type: Easing.OutBack
                duration: theme.animationDuration * 2
            }
        }
    }
}

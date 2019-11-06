import QtQuick 2.12
import QtQuick.Controls 2.12

ProgressBar {
    id: bar

    property color backgroundColor: theme.controls.progressBar.background
    property color foregroundColor: theme.controls.progressBar.foreground

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: theme.controls.progressBar.height
        color: backgroundColor
    }

    contentItem: Item {
        implicitWidth: 200
        implicitHeight: theme.controls.progressBar.height

        Rectangle {
            id: indicator
            width: bar.indeterminate ?
                   parent.width / 8 : bar.visualPosition * parent.width
            height: parent.height
            color: foregroundColor

            XAnimator on x {
                running: indeterminate
                duration: theme.animationDuration * 8
                from: 0
                to: bar.width - indicator.width
                onStopped: {[from, to] = [to, from]; start()}
            }
        }
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../Base"
import "../Base/ButtonLayout"

HColumnPopup {
    id: popup


    property string userId
    property string roomId
    property string roomName
    property bool invitingAllowed: true

    property var inviteFuture: null
    property var successfulInvites: []
    property var failedInvites: []


    function invite() {
        inviteButton.loading = true

        const inviteesLeft = inviteArea.text.trim().split(/\s+/).filter(
            user => ! successfulInvites.includes(user)
        )

        inviteFuture = py.callClientCoro(
            userId,
            "room_mass_invite",
            [roomId, ...inviteesLeft],

            ([successes, errors]) => {
                if (errors.length < 1) {
                    popup.close()
                    return
                }

                successfulInvites    = successes
                failedInvites        = errors
                inviteButton.loading = false
            }
        )
    }


    page.footer: ButtonLayout {
        ApplyButton {
            id: inviteButton
            text: qsTr("Invite")
            icon.name: "room-send-invite"
            enabled: invitingAllowed && Boolean(inviteArea.text.trim())
            onClicked: invite()
        }

        CancelButton {
            id: cancelButton
            onClicked: popup.close()
        }
    }

    onOpened: inviteArea.forceActiveFocus()
    onClosed: if (inviteFuture) inviteFuture.cancel()

    onInvitingAllowedChanged:
        if (! invitingAllowed && inviteFuture) inviteFuture.cancel()


    SummaryLabel {
        text: qsTr("Invite members to <i>%1</i>").arg(roomName)
        textFormat: Text.StyledText
    }

    HScrollView {
        clip: true

        Layout.fillWidth: true
        Layout.fillHeight: true

        HTextArea {
            id: inviteArea
            focusItemOnTab: inviteButton.enabled ? inviteButton : cancelButton
            placeholderText:
                qsTr("User IDs (e.g. @bob:matrix.org @alice:localhost)")
        }
    }

    HLabel {
        id: errorMessage
        visible: Layout.maximumHeight > 0
        wrapMode: Text.Wrap
        color: theme.colors.errorText
        text:
            invitingAllowed ?
            allErrors :
            qsTr("You do not have permission to invite members to this room")

        Layout.maximumHeight: text ? implicitHeight : 0
        Layout.fillWidth: true

        readonly property string allErrors: {
            // TODO: handle these: real user not found
            const lines = []

            for (const [user, error] of failedInvites) {
                const type = py.getattr(
                    py.getattr(error, "__class__"), "__name__",
                )

                lines.push(
                    type === "InvalidUserId" ?
                    qsTr("%1 is not a valid user ID, expected format is " +
                         "@username:homeserver").arg(user) :

                    type === "UserFromOtherServerDisallowed" ?
                    qsTr("This room rejects users from other matrix " +
                         "servers, can't invite %1").arg(user) :

                    type === "MatrixNotFound" ?
                    qsTr("%1 not found, please verify the entered ID")
                    .arg(user) :

                    type === "MatrixBadGateway" ?
                    qsTr("Could not contact %1's server, " +
                         "please verify the entered ID").arg(user) :

                    type === "MatrixUnsupportedRoomVersion" ?
                    qsTr("%1's server does not support this room's version")
                    .arg(user) :

                    type === "MatrixForbidden" ?
                    qsTr("%1 is banned from this room")
                    .arg(user) :

                    qsTr("Unknown error while inviting %1: %2 - %3")
                    .arg(user).arg(type).arg(py.getattr(error, "args"))
                )
            }

            return lines.join("\n\n")
        }

        Behavior on Layout.maximumHeight { HNumberAnimation {} }
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

import QtQuick 2.12
import Qt.labs.platform 1.1
import "../Popups"

HFileDialogOpener {
    fill: false
    dialog.title: qsTr("Save decryption keys file as...")
    dialog.fileMode: FileDialog.SaveFile
    onFilePicked: {
        exportPasswordPopup.file = file
        exportPasswordPopup.open()
    }


    // This is used for the SignOutPopup to know when the export is done
    // so it can close
    signal done()


    property string userId: ""
    property bool exporting: false


    function exportKeys(file, passphrase) {
        exporting = true

        const path = file.toString().replace(/^file:\/\//, "")

        py.callClientCoro(userId, "export_keys", [path, passphrase], () => {
            exporting = false
            done()
        })
    }


    PasswordPopup {
        id: exportPasswordPopup
        summary.text: qsTr("Passphrase to protect this file:")
        validateButton.text: qsTr("Export")
        validateButton.icon.name: "export-keys"

        onAcceptedPasswordChanged: exportKeys(file, acceptedPassword)

        property url file: ""
    }
}

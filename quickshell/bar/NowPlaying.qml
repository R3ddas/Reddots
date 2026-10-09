// Lo que se está reproduciendo, arriba del todo del popup de volumen (Volume.qml): el
// reproductor, la carátula, el título y el artista, el avance de la canción y los controles
// (anterior, play/pausa, siguiente). Solo se ve si hay algún reproductor abierto.
//   Clic en la carátula o el título: trae el reproductor al frente
//   "1/2 ›": pasa al siguiente reproductor, si hay varios
import Quickshell
import Quickshell.Services.Mpris      // Para lo que se está reproduciendo (título, carátula, play/pausa...)
import Quickshell.Widgets             // Para el ClippingRectangle de la carátula
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Todo va comprobando root.player !== null: aunque esté oculto (sin reproductor), sus
// bindings se siguen calculando, y sin reproductor darían error.
ColumnLayout {
    id: root

    property bool popupOpen: false      // El popup que lo contiene está abierto: solo entonces se actualiza el avance (ver el Timer)
    signal raised()                     // Se ha traído el reproductor al frente: quien lo contiene puede cerrarse para no taparlo

    visible: player !== null
    Layout.fillWidth: true
    spacing: 6

    // Los reproductores que se anuncian por MPRIS: Spotify, mpv, y Chrome/Zen con un vídeo o
    // música en alguna pestaña (cada pestaña con algo sonando es un reproductor). Es lo mismo
    // que usan las teclas multimedia (playerctl, en hypr/keybinds.lua).
    // Se muestra el que haya elegido el usuario con "n/N" (si sigue abierto); si no, el que
    // esté sonando, y si no suena ninguno, el primero.
    readonly property var players: Mpris.players.values
    property var chosenPlayer: null
    readonly property var player: players.includes(chosenPlayer) ? chosenPlayer
                                : players.find(p => p.isPlaying) ?? players[0] ?? null

    function nextPlayer() {
        chosenPlayer = players[(players.indexOf(player) + 1) % players.length]
    }

    // Segundos -> "3:07" o "1:02:03"
    function formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec
    }

    // "position" no se actualiza sola (Quickshell lo evita para no gastar CPU sin que nadie
    // mire): mientras el popup está abierto y suena algo, se le pide cada segundo, como
    // indica su documentación
    Timer {
        running: root.popupOpen && root.player !== null && root.player.isPlaying && root.player.positionSupported
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Botón de los controles de reproducción (anterior, play/pausa, siguiente). Con
    // enabled: false (el reproductor no lo permite) sale apagado y no responde
    component MediaButton: TextButton {
        color: enabled ? Theme.textActive : Theme.textDisabled
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        Layout.preferredWidth: 28
    }

    RowLayout {                         // Título con el nombre del reproductor + "1/2 ›" para cambiar de uno a otro
        Layout.fillWidth: true
        Text {                          // Como los títulos de las demás partes del popup
            text: "Reproduciendo" + (root.player && root.player.identity ? " · " + root.player.identity : "")
            color: Theme.textDisabled
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        TextButton {
            visible: root.players.length > 1
            text: (root.players.indexOf(root.player) + 1) + "/" + root.players.length + " ›"
            font.pixelSize: 11
            onClicked: root.nextPlayer()
        }
    }

    Item {                              // Carátula + título y artista; al pulsar, trae el reproductor al frente
        Layout.fillWidth: true
        implicitHeight: trackRow.implicitHeight

        RowLayout {
            id: trackRow
            anchors.fill: parent
            spacing: 8

            ClippingRectangle {         // Carátula (con esquinas redondeadas); sin ella, una nota musical
                implicitWidth: 44
                implicitHeight: 44
                radius: 6
                color: Theme.background

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: String.fromCodePoint(0xF075A)      // music-note
                    color: Theme.textDisabled
                    font.pixelSize: 20
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 88                     // Se decodifica ya reducida (al doble, para que se vea nítida)
                    sourceSize.height: 88
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: root.player ? (root.player.trackTitle || "Sin título") : ""
                    textFormat: Text.PlainText                // Viene de la app (como en Notifications.qml)
                    color: Theme.textActive
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: text !== ""
                    text: root.player ? (root.player.trackArtist || root.player.trackAlbum) : ""
                    textFormat: Text.PlainText
                    color: Theme.textDisabled
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.player !== null && root.player.canRaise
            onClicked: {
                root.player.raise()
                root.raised()
            }
        }
    }

    // Avance de la canción: se puede arrastrar o usar la rueda si el reproductor lo permite
    Slider {
        visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
        interactive: root.player !== null && root.player.canSeek && root.player.positionSupported
        barHeight: 8
        value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
        label: root.player ? root.formatTime(root.player.position) + " / " + root.formatTime(root.player.length) : ""
        onMoved: v => root.player.position = Math.max(0, Math.min(1, v)) * root.player.length
    }

    RowLayout {                         // Anterior · play/pausa · siguiente
        Layout.alignment: Qt.AlignHCenter
        spacing: 16
        MediaButton {
            text: String.fromCodePoint(0xF04AE)             // skip-previous
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: root.player.previous()
        }
        MediaButton {
            text: String.fromCodePoint(root.player && root.player.isPlaying ? 0xF03E4 : 0xF040A)   // pause / play
            enabled: root.player !== null && root.player.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }
        MediaButton {
            text: String.fromCodePoint(0xF04AD)             // skip-next
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }
    }
}

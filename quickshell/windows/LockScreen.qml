// LockScreen.qml
// Lo que se ve en cada monitor con la pantalla bloqueada (el estado y la contraseña están
// en Lock.qml): el fondo de pantalla desenfocado y velado con el fondo del tema, la hora y
// la fecha, el usuario y el campo de la contraseña (sin recuadro), y abajo los botones de
// apagar, reiniciar y suspender.
//   Intro: desbloquear   ·   Esc: borrar lo escrito
// Al bloquear, el desenfoque, el velo y el contenido entran con una animación corta
// ("progress"), así el paso desde el escritorio no es un corte seco.

import Quickshell
import Quickshell.Io                    // FileView, para el nombre del usuario
import QtQuick
import QtQuick.Effects                  // MultiEffect, para desenfocar el fondo
import QtQuick.Layouts
import qs.components
import qs.services

Item {
    id: root

    property var lock: null             // El Lock.qml que la crea
    readonly property var spanish: Qt.locale("es_ES")      // Días y meses en español, sea cual sea el idioma del sistema

    property real progress: 0           // 0 → 1 al aparecer
    NumberAnimation on progress { from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }

    clip: true                          // El fondo se dibuja algo más grande que la pantalla (ver wallpaper)

    // Halo del fondo del tema alrededor de lo que va directamente sobre la imagen (la hora,
    // la fecha, el nombre...): con un fondo muy claro y un tema oscuro (o al revés) el velo
    // solo no basta para leerlo. Se pone con "layer.enabled: true; layer.effect: Halo {}".
    component Halo: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.background
        blurMax: 12                     // Halo corto y denso: con el de por defecto (32) se repartía tanto que casi no se veía
        shadowBlur: 1.0
        shadowOpacity: 1.0
        shadowScale: 1.02
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    // Nombre del usuario: el "nombre completo" de /etc/passwd (el campo GECOS, el que se
    // cambia con chfn) o, si está vacío, el nombre de la cuenta; con la primera en mayúscula.
    FileView {
        id: passwd
        path: "/etc/passwd"
        blockLoading: true              // Pequeño: así text() ya tiene el contenido al calcular userName
    }
    readonly property string userName: {
        const user = Quickshell.env("USER")
        const line = passwd.text().split("\n").find(l => l.startsWith(user + ":"))
        const name = (line ? line.split(":")[4].split(",")[0] : "") || user
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    // --- Fondo ----------------------------------------------------------------
    // El mismo fondo de pantalla del escritorio (Wallpaper.path). Sobresale de la pantalla
    // lo que mide el desenfoque: en los bordes el desenfoque mezcla con lo que hay fuera de
    // la imagen y, si no sobrase, los bordes se verían oscuros. Se carga sin "asynchronous":
    // así el primer fotograma del bloqueo ya trae el fondo (y no un instante de color liso).
    Image {
        id: wallpaper
        anchors.fill: parent
        anchors.margins: -blur.blurMax
        source: Wallpaper.path ? "file://" + Wallpaper.path : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: width
        sourceSize.height: height
        visible: false                  // Lo pinta el MultiEffect, ya desenfocado
    }

    MultiEffect {
        id: blur
        anchors.fill: wallpaper
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.progress
    }

    // Velo con el fondo del tema: el texto se lee sobre cualquier imagen, y la pantalla de
    // bloqueo sale clara u oscura según el tema, como el resto de la interfaz
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.7 * root.progress
    }

    // Un clic en cualquier sitio devuelve el foco al campo (por si se ha perdido)
    MouseArea {
        anchors.fill: parent
        onClicked: field.input.forceActiveFocus()
    }

    // --- Hora, fecha, usuario y contraseña ---------------------------------------
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30   // Algo por encima del centro: abajo están los botones
        spacing: 0
        opacity: root.progress
        scale: 0.96 + 0.04 * root.progress

        // Hora y fecha, con el halo (ver Halo) y un pelín translúcidas, para que no pesen tanto
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            opacity: 0.85
            layer.enabled: true
            layer.effect: Halo {}

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "hh:mm")
                color: Theme.textActive
                font.pixelSize: 110
                font.bold: true
            }

            Text {                          // "Lunes, 6 de octubre"
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const date = root.spanish.toString(clock.date, "dddd, d 'de' MMMM")
                    return date.charAt(0).toUpperCase() + date.slice(1)
                }
                color: Theme.textActive
                font.pixelSize: 22
            }
        }

        // Usuario y contraseña, sin recuadro: directamente sobre el fondo, como la hora.
        // Es un Item y no solo el ColumnLayout para poder sacudirlo entero al fallar.
        Item {
            id: card
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 48
            implicitWidth: 340
            implicitHeight: cardContent.implicitHeight + 48

            // Sacudida al fallar la contraseña
            transform: Translate { id: shakeOffset }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeOffset; property: "x"; to: -12; duration: 50 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 12; duration: 70 }
                NumberAnimation { target: shakeOffset; property: "x"; to: -8; duration: 60 }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50 }
            }
            Connections {
                target: root.lock
                function onFailuresChanged() { shake.restart() }
            }

            ColumnLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.userName
                    textFormat: Text.PlainText
                    // Halo solo en los textos y no en toda la columna: el campo de la contraseña ya
                    // tiene su fondo, y el halo (algo más grande que lo que rodea) asomaba por sus lados
                    layer.enabled: true
                    layer.effect: Halo {}
                    color: Theme.textActive
                    font.pixelSize: 18
                    font.bold: true
                }

                InputField {
                    id: field
                    Layout.topMargin: 4
                    // Borde del color de los números de la hora (el texto del tema, con su misma
                    // transparencia), con foco o sin él: aquí el campo siempre tiene el foco
                    border.color: Qt.alpha(Theme.textActive, 0.85)
                    placeholder: root.lock && root.lock.checking ? "Comprobando…" : "Contraseña"
                    input.echoMode: TextInput.Password
                    input.passwordCharacter: "•"
                    input.font.pointSize: Qt.application.font.pointSize + 1    // Un punto más que la letra normal (también el texto de ayuda, ver InputField)
                    input.readOnly: root.lock ? root.lock.checking : false     // readOnly y no enabled: así Esc sigue funcionando
                    onAccepted: root.lock.submit()
                    onEscapePressed: root.lock.password = ""
                    // Lo escrito va a Lock.qml (y de ahí al campo de los demás monitores, abajo)
                    onTextChanged: if (root.lock && root.lock.password !== text) root.lock.password = text

                    Connections {
                        target: root.lock
                        function onPasswordChanged() {
                            if (field.text !== root.lock.password) field.text = root.lock.password
                        }
                    }
                    Component.onCompleted: input.forceActiveFocus()
                }

                Text {                      // Avisos: contraseña incorrecta o lo que diga PAM
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.lock ? root.lock.message : ""
                    textFormat: Text.PlainText      // Viene de PAM: que no se interprete como HTML
                    layer.enabled: true
                    layer.effect: Halo {}
                    color: root.lock && root.lock.messageIsError ? Theme.error : Theme.textDisabled
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // --- Apagar, reiniciar y suspender -----------------------------------------
    // Con texto y no solo el icono: en esta pantalla no hay descripciones al pasar el ratón
    // (los BarTooltip son ventanas emergentes de la barra). Los mismos glifos que Power.qml.
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40
        spacing: 12
        // Los tres igual de anchos (el del más largo, "Suspender"): así el del medio queda
        // justo en el centro de la pantalla, alineado con la hora y el campo
        uniformCellSizes: true
        opacity: root.progress

        Repeater {
            model: [
                { icon: 0xF0425, label: "Apagar",    command: ["systemctl", "poweroff"] },    // power
                { icon: 0xF0709, label: "Reiniciar", command: ["systemctl", "reboot"] },      // restart
                { icon: 0xF0904, label: "Suspender", command: ["systemctl", "suspend"] }      // power-sleep
            ]

            // El icono va más grande que el texto, así que no cabe en el texto único de Button:
            // el botón se queda sin texto y lleva dentro su propia fila de icono + texto (y
            // mide lo que ella más "padding" a cada lado, como Button con su texto)
            delegate: Button {
                id: powerButton
                required property var modelData
                padding: 18
                implicitWidth: powerContent.implicitWidth + padding * 2
                implicitHeight: 42
                Layout.fillWidth: true          // Ocupa toda su celda (ver uniformCellSizes)
                // Translúcidos, porque son secundarios y no deben competir con la hora ni el campo:
                // el recuadro (relleno y borde) al 40 % y el icono y el texto algo más visibles
                // (powerContent, 65 %). Con el color y no con "opacity" del botón entero, que
                // también apagaría el texto. El relleno es el del campo de la contraseña
                // (InputField): el fondo del tema, el color del velo, así que se funde con él.
                color: Qt.alpha(hovered ? Theme.surfaceHover : Theme.background, 0.4)
                border.color: Qt.alpha(Theme.border, 0.4)
                onClicked: root.lock.power(modelData.command)       // Ver power() en Lock.qml

                RowLayout {
                    id: powerContent
                    anchors.centerIn: parent
                    spacing: 8
                    opacity: 0.65

                    Text {
                        text: String.fromCodePoint(powerButton.modelData.icon)
                        color: Theme.textActive
                        font.pixelSize: 20
                    }
                    Text {
                        text: powerButton.modelData.label
                        color: Theme.textActive
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}

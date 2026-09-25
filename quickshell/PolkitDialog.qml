// PolkitDialog.qml
// Ventana que pide la contraseña cuando una aplicación necesita permisos de
// administrador (montar un disco en Nemo, cambiar la hora, instalar algo desde una
// app gráfica...). Sustituye a hyprpolkitagent: es lo mismo, pero con los colores
// del tema. El agente en sí (PolkitAgent, el que se registra en el sistema) vive en
// shell.qml, fuera del Variants de la pantalla, para que no se dé de baja cuando la
// pantalla desaparece; esta ventana solo lo muestra.
//   Intro: autenticar   ·   Esc o "Cancelar": cancelar
// Probar: pkexec true (y luego "echo $?": 0 = autorizado, 126 = cancelado)

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    property PolkitAgent agent: null
    readonly property AuthFlow flow: agent ? agent.flow : null

    visible: flow !== null

    // Sin anchors: el compositor la coloca en el centro de la pantalla
    implicitWidth: 420
    implicitHeight: content.implicitHeight + 40

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:polkit"
    // Exclusive: mientras está abierta, todo el teclado va a ella (que la contraseña no
    // acabe escrita en otra ventana por un clic). No se cierra al pulsar fuera.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        passwordInput.text = ""
        if (visible) passwordInput.forceActiveFocus()
        else passwordInput.focus = false        // Nada con foco mientras está cerrada (ver Keybinds.qml)
    }

    // Cada vez que polkit pide otra vez la contraseña (p.ej. tras fallarla), campo vacío y con el foco
    Connections {
        target: root.flow
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired) {
                passwordInput.text = ""
                passwordInput.forceActiveFocus()
            }
        }
    }

    function submit() {
        if (!flow || !flow.isResponseRequired) return
        flow.submit(passwordInput.text)
        passwordInput.text = ""                 // No se queda la contraseña en memoria más de lo necesario
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest()
    }

    // Botón de la parte de abajo (Cancelar / Autenticar)
    component DialogButton: Rectangle {
        id: button
        property string text
        property bool accent: false
        property bool enabled: true
        signal clicked()

        implicitWidth: label.implicitWidth + 28
        implicitHeight: 30
        radius: 6
        color: !enabled ? "transparent"
             : accent ? (buttonMouse.containsMouse ? Theme.surfaceHover : Theme.background)
             : (buttonMouse.containsMouse ? Theme.surfaceHover : "transparent")
        border.width: 1
        border.color: accent && enabled ? Theme.textSelected : Theme.border

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            textFormat: Text.PlainText
            color: button.enabled ? (button.accent ? Theme.textSelected : Theme.textActive) : Theme.textDisabled
            font.bold: button.accent
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Geometry.popupRounding              // Mismo estilo que los desplegables de la barra
        border.color: Theme.textSelected
        border.width: Geometry.popupBorderWidth

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {                             // Icono + título
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: String.fromCodePoint(0xF0341)     // lock
                    color: Theme.textSelected
                    font.pixelSize: 26
                }
                Text {
                    text: "Se necesita autorización"
                    color: Theme.textSelected
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }
            }

            // Lo que pide la aplicación ("Se necesita autenticación para montar...").
            // PlainText: el texto viene de fuera y no debe interpretarse como HTML.
            Text {
                text: root.flow ? root.flow.message : ""
                textFormat: Text.PlainText
                color: Theme.textActive
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Con qué usuario se autentica. Si polkit ofrece varios (p.ej. varios
            // administradores), un clic pasa al siguiente.
            Text {
                readonly property var identities: root.flow ? Array.from(root.flow.identities) : []
                readonly property var selected: root.flow ? root.flow.selectedIdentity : null
                visible: selected !== null
                text: String.fromCodePoint(0xF0004) + "  " + (selected ? (selected.displayName || selected.string) : "")   // account
                      + (identities.length > 1 ? "   (clic para cambiar)" : "")
                textFormat: Text.PlainText
                color: Theme.textDisabled
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    enabled: parent.identities.length > 1
                    onClicked: {
                        const list = parent.identities
                        root.flow.selectedIdentity = list[(list.indexOf(parent.selected) + 1) % list.length]
                    }
                }
            }

            Rectangle {                             // Campo de la contraseña
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: Theme.background
                border.color: passwordInput.activeFocus ? Theme.textSelected : Theme.border

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textActive
                    selectionColor: Theme.surfaceHover
                    clip: true
                    readOnly: root.flow ? !root.flow.isResponseRequired : true       // Mientras se comprueba, no se puede escribir (readOnly y no enabled: así Esc sigue funcionando)
                    echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()      // Intro del teclado numérico
                    Keys.onEscapePressed: root.cancel()

                    Text {                          // Lo que pide PAM, mientras el campo está vacío
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text === ""
                        // PAM suele pedir "Password:" en inglés: ese se traduce; si pide otra cosa
                        // (p.ej. el PIN de una llave de seguridad), se muestra tal cual
                        readonly property string prompt: root.flow ? root.flow.inputPrompt.replace(/:\s*$/, "") : ""
                        text: !root.flow ? ""
                            : !root.flow.isResponseRequired ? "Comprobando…"
                            : (prompt === "" || /^password$/i.test(prompt)) ? "Contraseña"
                            : prompt
                        textFormat: Text.PlainText
                        color: Theme.textDisabled
                    }
                }
            }

            // Avisos: el que mande polkit/PAM o, si no manda ninguno, el de contraseña incorrecta
            Text {
                readonly property string message: !root.flow ? ""
                    : root.flow.supplementaryMessage !== "" ? root.flow.supplementaryMessage
                    : root.flow.failed ? "Contraseña incorrecta, prueba otra vez"
                    : ""
                readonly property bool isError: root.flow && (root.flow.supplementaryMessage !== "" ? root.flow.supplementaryIsError : root.flow.failed)
                visible: message !== ""
                text: message
                textFormat: Text.PlainText
                color: isError ? "#ff0000" : Theme.textDisabled     // Rojo fijo, como el borde de las notificaciones críticas
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {                             // Botones
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Item { Layout.fillWidth: true }     // Empuja los botones a la derecha

                DialogButton {
                    text: "Cancelar"
                    onClicked: root.cancel()
                }
                DialogButton {
                    text: "Autenticar"
                    accent: true
                    enabled: root.flow ? root.flow.isResponseRequired : false
                    onClicked: root.submit()
                }
            }
        }
    }
}

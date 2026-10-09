// Campo de texto con el estilo del tema: recuadro, texto y un texto de ayuda en gris
// ("placeholder") mientras está vacío. Lo usan los buscadores del Launcher y del
// portapapeles (Clipboard.qml), los campos de wifi (Network.qml) y la contraseña de
// PolkitDialog.qml.
//
// Lo que no está aquí se le pone al TextInput de dentro a través de "input"
// (input.echoMode, input.readOnly, input.focus...). Las teclas llegan como señales:
//   accepted()        Intro (también el del teclado numérico)
//   escapePressed()   Esc
//   keyPressed(event) cualquier otra tecla (p.ej. Shift + Supr en el portapapeles)
// Con "list" hace además de buscador: ↑ ↓ mueven la selección de esa lista y, al
// escribir, vuelve a seleccionarse el primer resultado.
import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
    id: root

    property alias input: input
    property alias text: input.text
    property string placeholder: ""
    property int padding: 12            // Margen del texto a izquierda y derecha
    property bool highlightFocus: false // Borde con el color de acento mientras tiene el foco
    property ListView list: null        // Lista que maneja como buscador (ver arriba)
    property Item next: null            // Campo al que se pasa con Tab (otro InputField)

    signal accepted()
    signal escapePressed()
    signal keyPressed(var event)

    Layout.fillWidth: true
    implicitHeight: 36
    radius: 8
    color: Theme.background
    border.color: highlightFocus && input.activeFocus ? Theme.textSelected : Theme.border

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.textActive
        selectionColor: Theme.surfaceHover
        clip: true

        KeyNavigation.tab: root.next ? root.next.input : null
        onAccepted: root.accepted()
        onTextChanged: if (root.list) root.list.currentIndex = 0       // Al filtrar, se selecciona el primer resultado
        Keys.onUpPressed: if (root.list) root.list.currentIndex = Math.max(root.list.currentIndex - 1, 0)
        Keys.onDownPressed: if (root.list) root.list.currentIndex = Math.min(root.list.currentIndex + 1, root.list.count - 1)
        Keys.onEscapePressed: root.escapePressed()
        Keys.onPressed: event => root.keyPressed(event)

        Text {                          // Texto de ayuda mientras el campo está vacío
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            textFormat: Text.PlainText  // Puede venir de fuera (lo que pide PAM en PolkitDialog.qml): que no se interprete como HTML
            color: Theme.textDisabled
            font: input.font            // La misma letra que lo que se escribe: quien cambie input.font cambia las dos
        }
    }
}

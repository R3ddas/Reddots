// Launcher.qml
// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// Lista las aplicaciones instaladas (con icono) y las lanza al hacer click
// Al abrirse ya se puede escribir para filtrar: flechas para moverse, Intro para lanzar, Esc para cerrar

import Quickshell
import Quickshell.Io       // Para el IpcHandler
import Quickshell.Hyprland // Para el HyprlandFocusGrab
import Quickshell.Wayland
import Quickshell.Widgets  // Para el IconImage
import QtQuick
import QtQuick.Layouts     // Para RowLayout

PanelWindow {
    id: root
    visible: false

    anchors { bottom: true; right: true }

    implicitWidth: 320
    implicitHeight: 480

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "reddots:launcher"
    // OnDemand y no Exclusive: con Exclusive Hyprland no deja salir el clic y el
    // HyprlandFocusGrab nunca se entera de que se ha pulsado fuera (no se cerraba).
    // El teclado le llega igual al abrirse, porque se lo da el propio grab.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""                       // Cada vez que se abre empieza sin filtro
            list.currentIndex = 0
            searchInput.forceActiveFocus()
            grabTimer.restart()
        } else {
            grabTimer.stop(); grab.active = false
        }
    }

    // Aplicaciones instaladas (sin las ocultas), ordenadas por nombre
    property var apps: {
        let list = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        list.sort((a, b) => a.name.localeCompare(b.name))
        return list
    }

    // Quita mayúsculas y tildes, para que "musica" encuentre "Música"
    function normalize(s) {
        return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    }

    // Las que coinciden con lo escrito, buscando en el nombre, el nombre genérico
    // ("Navegador web") y las palabras clave del .desktop
    property var filteredApps: {
        const query = normalize(searchInput.text.trim())
        if (query === "") return apps
        return apps.filter(e => normalize([e.name, e.genericName, ...(e.keywords || [])].join(" ")).includes(query))
    }

    function launch(entry) {
        if (!entry) return
        entry.execute()
        root.visible = false
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.rightMargin: -border.width      // Los bordes derecho e inferior quedan fuera de la ventana: solo se ve el borde
        anchors.bottomMargin: -border.width     // de arriba y el de la izquierda, no una línea pegada al filo de la pantalla
        topLeftRadius: 24        // Solo la esquina superior izquierda es redondeada, el resto llega al borde de la pantalla
        color: Theme.surface
        border.color: Theme.textSelected        // Borde con el color de acento del tema, como los desplegables de la barra
        border.width: Geometry.popupBorderWidth // Grosor editable en GeometrySettings
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            anchors.rightMargin: 12 + background.border.width   // Compensa el borde que queda fuera de la ventana
            anchors.bottomMargin: 12 + background.border.width
            spacing: 8

            Rectangle {                         // Campo de búsqueda
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: Theme.background
                border.color: Theme.border

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textActive
                    selectionColor: Theme.surfaceHover
                    clip: true

                    onTextChanged: list.currentIndex = 0   // Al filtrar, se selecciona el primer resultado

                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
                    Keys.onReturnPressed: root.launch(root.filteredApps[list.currentIndex])
                    Keys.onEnterPressed: root.launch(root.filteredApps[list.currentIndex])    // Intro del teclado numérico
                    Keys.onEscapePressed: root.visible = false

                    Text {                      // Texto de ayuda mientras el campo está vacío
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Buscar…"
                        color: Theme.textDisabled
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.filteredApps
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)  // Hace scroll para que el seleccionado se vea

                Text {
                    visible: list.count === 0
                    text: "Sin resultados"
                    color: Theme.textDisabled
                }

                delegate: Rectangle {
                    id: appDelegate
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: 44
                    radius: 8
                    color: ListView.isCurrentItem ? Theme.surfaceHover : "transparent"   // El ratón y las flechas mueven la misma selección

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        IconImage {
                            implicitSize: 28
                            source: Quickshell.iconPath(appDelegate.modelData.icon, "application-x-executable")
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: appDelegate.modelData.name
                            color: Theme.textActive
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = appDelegate.index
                        onClicked: root.launch(appDelegate.modelData)
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.visible = !root.visible
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: false
        onCleared: root.visible = false   // Se cierra al hacer click fuera
    }

    Timer {
        id: grabTimer
        interval: 5
        onTriggered: grab.active = true
    }
}

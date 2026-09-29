// Launcher.qml
// Widget que aparece al pulsar Super solo (sin combinar con otra tecla), anclado abajo-derecha
// Lista las aplicaciones instaladas (con icono) y las lanza al hacer click
// Al abrirse ya se puede escribir para filtrar: flechas para moverse, Intro para lanzar, Esc para cerrar

import Quickshell
import Quickshell.Io       // Para el IpcHandler
import Quickshell.Wayland
import Quickshell.Widgets  // Para el IconImage
import QtQuick
import QtQuick.Layouts     // Para RowLayout
import qs.components
import qs.services

OverlayWindow {             // Se cierra al hacer clic fuera (ver OverlayWindow.qml)
    id: root

    anchors { bottom: true; right: true }

    implicitWidth: 320
    implicitHeight: 480

    WlrLayershell.namespace: "reddots:launcher"

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""                       // Cada vez que se abre empieza sin filtro
            list.currentIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    // Aplicaciones instaladas (sin las ocultas)
    property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // Qué tal coincide una app con lo escrito: cuanto más bajo, más arriba sale; -1 = no coincide.
    //   0: el nombre empieza por lo escrito                     ("fi" -> "Firefox")
    //   1: alguna palabra del nombre empieza por lo escrito     ("code" -> "Visual Studio Code")
    //   2: el nombre lo contiene en medio
    //   3: lo contiene el nombre genérico ("Navegador web") o las palabras clave del .desktop
    function matchRank(entry, query) {
        const name = Search.normalize(entry.name)
        if (name.startsWith(query)) return 0
        if (name.split(/[\s\-_.]+/).some(word => word.startsWith(query))) return 1
        if (name.includes(query)) return 2
        if (Search.normalize([entry.genericName, ...(entry.keywords || [])].join(" ")).includes(query)) return 3
        return -1
    }

    // Lo que se ve en la lista. Sin nada escrito: primero las más usadas (AppUsage.qml) y
    // luego el resto por nombre. Escribiendo: por cómo coinciden (matchRank) y, dentro de
    // cada grupo, igual: las más usadas primero y luego por nombre.
    property var filteredApps: {
        const query = Search.normalize(searchInput.text.trim())
        const list = apps.map(e => ({ entry: e, rank: query === "" ? 0 : matchRank(e, query), uses: AppUsage.count(e) }))
                         .filter(a => a.rank >= 0)
        list.sort((a, b) => a.rank - b.rank || b.uses - a.uses || a.entry.name.localeCompare(b.entry.name))
        return list.map(a => a.entry)
    }

    function launch(entry) {
        if (!entry) return
        AppUsage.record(entry)                      // Para que la próxima vez salga más arriba
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
}

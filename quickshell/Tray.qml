// Tray.qml
// Bandeja del sistema: un icono por cada app que deja uno (Steam, Teams, Claude...).
// Sin esto, al cerrar la ventana de esas apps no había forma de volver a abrirlas.
//   Clic izquierdo: abre la app (o su menú, si la app solo tiene menú)
//   Clic derecho:   su menú, pintado aquí con los colores del tema (como los demás desplegables)
//   Clic central:   la acción secundaria de la app, si tiene
//   Rueda:          se le pasa a la app (algunas cambian el volumen, etc.)
// Si no hay ninguna app con icono, el widget no ocupa sitio en la barra.

import Quickshell
import Quickshell.Widgets               // Para el IconImage
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 8
    visible: icons.count > 0

    // Algunas apps (Steam, apps de Electron...) mandan el icono como "nombre?path=carpeta"
    // en vez de un nombre del tema de iconos, y así no se encuentra: se convierte en la ruta del archivo
    function iconSource(icon) {
        if (!icon.includes("?path=")) return icon
        const [name, path] = icon.split("?path=")
        return "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1)
    }

    Repeater {
        id: icons
        model: SystemTray.items

        delegate: IconImage {
            id: trayIcon
            required property SystemTrayItem modelData

            visible: modelData.status !== Status.Passive    // "Passive" = la app pide que no se muestre ahora mismo
            implicitSize: 18
            source: root.iconSource(modelData.icon)
            Layout.alignment: Qt.AlignHCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    const item = trayIcon.modelData
                    if (event.button === Qt.MiddleButton) item.secondaryActivate()
                    else if (event.button === Qt.RightButton || item.onlyMenu) menu.openFor(item, trayIcon)
                    else item.activate()
                }
                onWheel: wheel => trayIcon.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }

    // --- Menú de la app ------------------------------------------------------------
    // Uno solo para todos los iconos: se engancha al que se ha pulsado.

    BarPopup {
        id: menu

        property int depth: 0               // 0 = menú principal, 1 = submenú, 2 = submenú de submenú...

        // Un QsMenuOpener por nivel, y no uno solo al que se le cambia el menú: al soltar un
        // menú, Quickshell lo cierra y tira sus entradas, incluidas las de sus submenús, así
        // que al entrar en uno salía vacío. Así el menú de arriba sigue abierto mientras se
        // está dentro de su submenú. Cuatro niveles sobran para un menú de bandeja.
        readonly property list<QsMenuOpener> levels: [level0, level1, level2, level3]
        readonly property QsMenuOpener current: levels[depth]      // El nivel que se está viendo

        function openFor(item, icon) {
            if (!item.hasMenu) return
            if (visible && level0.menu === item.menu && depth === 0) { visible = false; return }   // Segundo clic en el mismo icono: se cierra
            anchorItem = icon
            level0.menu = item.menu
            visible = true
        }

        function enter(entry) {                 // Entra en un submenú
            if (depth === levels.length - 1) return                     // Más niveles no hay (no debería pasar)
            levels[depth + 1].menu = entry
            depth++
        }

        function back() {                       // Vuelve al menú anterior
            depth--
            levels[depth + 1].menu = null
        }

        function closeAll() {                   // De dentro afuera, como se abrieron
            for (let i = levels.length - 1; i >= 0; i--) levels[i].menu = null
            depth = 0
        }

        implicitWidth: Math.min(Math.max(180, listCol.implicitWidth + 16), 340)
        implicitHeight: listCol.implicitHeight + 16

        onVisibleChanged: if (!visible) closeAll()

        // Leen las entradas del menú de la app (llegan por D-Bus)
        QsMenuOpener { id: level0 }
        QsMenuOpener { id: level1 }
        QsMenuOpener { id: level2 }
        QsMenuOpener { id: level3 }

        ColumnLayout {
            id: listCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            MenuRow {                                   // Solo dentro de un submenú
                visible: menu.depth > 0
                icon: "‹"
                text: "Atrás"
                onClicked: menu.back()
            }

            Repeater {
                model: menu.current.children

                delegate: Item {
                    id: entryItem
                    required property QsMenuEntry modelData

                    Layout.fillWidth: true
                    implicitWidth: modelData.isSeparator ? 0 : row.implicitWidth
                    implicitHeight: modelData.isSeparator ? 9 : row.implicitHeight

                    Rectangle {                         // Separador
                        visible: entryItem.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Theme.border
                    }

                    EntryRow {
                        id: row
                        visible: !entryItem.modelData.isSeparator
                        width: parent.width
                        entry: entryItem.modelData
                        onClicked: {
                            if (entry.hasChildren) menu.enter(entry)
                            else {
                                entry.triggered()       // Le dice a la app que se ha pulsado
                                menu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // Fila de una entrada del menú de la app, sobre la MenuRow común (la de Power.qml,
    // Screenshot.qml...): saca de la entrada el texto, si está activa, la marca de
    // casilla, su icono y la flecha de submenú.
    component EntryRow: MenuRow {
        required property QsMenuEntry entry
        readonly property bool checkable: entry.buttonType !== QsMenuButtonType.None

        text: entry.text                    // Quickshell ya quita los "_" de tecla rápida ("_Abrir" llega como "Abrir")
        active: entry.enabled
        arrow: entry.hasChildren
        icon: checkable && entry.checkState === Qt.Checked ? "✓" : ""
        iconSource: checkable ? "" : entry.icon   // El icono que pone la app, si lo pone (y no es casilla)
    }
}

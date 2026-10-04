// Icono en la barra + popup con lo relativo al propio repo Reddots:
//   - Atajos de teclado: abre la chuleta (Keybinds.qml). Este archivo solo avisa con
//     keybindsRequested(); quién la abre lo decide shell.qml.
//   - Actualizar Reddots: baja los cambios del repo (git pull) y ejecuta install.sh, en
//     un Alacritty para que sudo pueda pedir la contraseña y paru hacer sus preguntas.
//     El trabajo lo hace scripts/update-reddots.sh; esto solo lo lanza.
// Va arriba del todo de la barra, encima de los workspaces (Bar.qml), y con un paso más
// (el popup) para no lanzar sin querer una actualización de todo el sistema.
import Quickshell
import Quickshell.Io           // Para el FileView que lee el SVG del logo
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 6

    signal keybindsRequested()      // Se ha pulsado "Atajos de teclado"

    // El logo de Reddots (assets/ReddotsIcon.svg) en vez de un glifo de la Nerd Font, así que
    // no es un BarIcon: la zona de clic y el tooltip (TooltipArea.qml) van aquí, como en Tray.qml.
    // El SVG es de un solo color (blanco) y un Image no se puede teñir sin un efecto de
    // shader, así que se lee el archivo, se le cambia el relleno por el azul del tema (base0D,
    // el último color de la muestra de cada tema en ThemeSettings.qml) y se
    // le pasa al Image ya coloreado. Al cambiar de tema se vuelve a pintar solo.
    FileView {
        id: logoFile
        path: Quickshell.shellPath("assets/ReddotsIcon.svg")
        blockLoading: true                  // Es pequeño: así el icono sale ya en el primer fotograma
    }

    Image {
        id: logo
        Layout.preferredWidth: 18           // Lo que mide un glifo de BarIcon (font.pixelSize: 18)
        Layout.preferredHeight: 18
        sourceSize: Qt.size(36, 36)         // SVG rasterizado al doble para que no salga borroso al escalar
        source: "data:image/svg+xml;utf8," + encodeURIComponent(
                    logoFile.text().replace(/fill="[^"]*"/g, `fill="${Theme.base[13]}"`))
        Layout.alignment: Qt.AlignHCenter

        TooltipArea {
            tooltip: "Reddots: atajos de teclado y actualizar" + (Updates.count > 0 ? "\n" + Updates.summary : "")
            popup: menu
            onClicked: menu.toggle()
            // Updates.qml no mira por su cuenta: se consulta al acercar el ratón, y el
            // tooltip (y el aviso del menú) se actualizan solos cuando llega el resultado
            onContainsMouseChanged: if (containsMouse) Updates.refresh()
        }
    }

    BarPopup {
        id: menu
        anchorItem: logo
        implicitWidth: 240

        // Una fila por opción, como en Power.qml: icono, texto, qué hace al pulsarla
        // y, si hace falta, un aviso debajo de lo que va a pasar ("hint")
        Repeater {
            model: [
                { icon: 0xF030C, label: "Atajos de teclado",  run: () => root.keybindsRequested() },     // keyboard
                { icon: 0xF06B0, label: "Actualizar Reddots",                                             // update
                  hint: "Baja los cambios del repo y ejecuta install.sh en un terminal. Actualiza todo el sistema y pide la contraseña."
                        + (Updates.count > 0 ? "\n" + Updates.summary + "." : ""),
                  run: () => Quickshell.execDetached(["alacritty", "--title", "Actualizar Reddots", "-e",
                                Quickshell.shellPath("scripts/update-reddots.sh")]) }
            ]

            delegate: MenuRow {
                required property var modelData
                icon: String.fromCodePoint(modelData.icon)
                text: modelData.label
                hint: modelData.hint ?? ""
                onClicked: {
                    menu.visible = false
                    modelData.run()
                }
            }
        }
    }
}

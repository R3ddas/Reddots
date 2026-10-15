// Icono en la barra + popup para elegir el tema de color activo (Theme.qml).
// Cada fila muestra el nombre del tema y una muestra de sus colores; al
// pulsar una fila se aplica al momento y queda guardada (Theme.qml persiste
// activeTheme solo, igual que Geometry.qml con sus medidas).
// Arriba del todo, los sliders del brillo de las pantallas (BrightnessSliders.qml): al
// elegir tema es cuando más se mira cómo se ve la pantalla. Es el único sitio de la barra
// donde está el brillo (las teclas de brillo del portátil van aparte, en hypr/keybinds.lua).
// Debajo, el botón para crear el tema Wallpaper a partir del fondo de pantalla
// (services/WallpaperTheme.qml), que sale el primero de su sección (Claros u Oscuros).
// Los temas también se eligen con el teclado, como en los menús de ActionMenu.qml:
//   ↑ ↓     elegir un tema (la primera pulsación sale del activo; dan la vuelta)
//   Intro   aplicarlo (el menú sigue abierto, como al hacer clic, para probar otros)
//   Esc     cerrar
import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 6

    // Los temas de cada sección (Claros u Oscuros, según su fondo: ver Theme.isLight()), en el
    // orden de services/themes.js, salvo el tema Wallpaper (si existe), que va el primero de la
    // suya: es el que se crea desde el botón de arriba, y así no hay que bajar a buscarlo al final
    function sectionThemes(light) {
        const list = Theme.themes.filter(t => Theme.isLight(t) === light)
        const isWallpaper = t => t.name === WallpaperTheme.themeName
        return list.filter(isWallpaper).concat(list.filter(t => !isWallpaper(t)))
    }
    readonly property var lightThemes: sectionThemes(true)
    readonly property var darkThemes: sectionThemes(false)
    readonly property var orderedThemes: lightThemes.concat(darkThemes)     // Todos, en el orden en que se ven: el de las flechas

    // Tema elegido con las flechas o el ratón (su puesto en orderedThemes; -1 = ninguno, como al
    // abrir). El ratón y las flechas mueven el mismo, así que nunca hay dos filas resaltadas
    property int currentIndex: -1
    property bool followCurrent: false      // El elegido ha cambiado con las flechas: la lista se desplaza para que se vea

    function move(step) {
        const count = orderedThemes.length
        if (count === 0) return
        let from = currentIndex
        if (from < 0) from = orderedThemes.findIndex(t => t.name === Theme.activeTheme)   // La primera pulsación sale del tema activo
        followCurrent = true
        currentIndex = from < 0 ? (step > 0 ? 0 : count - 1) : (from + step + count) % count
    }

    function apply(index) {
        const theme = orderedThemes[index]
        if (theme) Theme.activeTheme = theme.name           // Intro sin ninguno elegido: no hace nada
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF195A)  // palette-swatch-variant
        tooltip: Lang.tr("Tema: %1", Theme.activeTheme)
        popup: menu
    }

    BarPopup {
        id: menu
        anchorItem: iconText
        implicitWidth: 220

        onVisibleChanged: {
            if (!visible) return
            BrightnessMonitor.refresh()                 // Relee el brillo real al abrir
            root.currentIndex = -1                      // Sin ninguno elegido (el activo ya se distingue por su borde y su ✓)
            themeList.forceActiveFocus()                // Para las flechas (el teclado le llega a la ventana con el grab de BarPopup)
        }

        // Fuera de la lista de temas (con scroll): así se quedan siempre arriba, aunque se baje
        // con la rueda para ver más temas
        BrightnessSliders {}

        Separator {
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        // Crea el tema Wallpaper a partir del fondo activo (services/WallpaperTheme.qml) y lo
        // aplica. Si ya existía, lo sustituye. También fuera de la lista, siempre a mano.
        MenuRow {
            icon: String.fromCodePoint(0xF02E9)         // image
            text: WallpaperTheme.generating ? Lang.tr("Creando tema…") : Lang.tr("Crear tema desde el fondo")
            tooltip: Lang.tr("Crea un tema con los colores del fondo de pantalla actual y lo aplica. Si ya habías creado uno, lo sustituye.")
            active: !WallpaperTheme.generating
            onClicked: WallpaperTheme.generate()
        }
        Connections {
            target: WallpaperTheme
            function onGenerated() { Theme.activeTheme = WallpaperTheme.themeName }
        }

        Separator {
            Layout.topMargin: 4
            Layout.bottomMargin: 4
        }

        // Con scroll (ScrollColumn) porque hay decenas de temas: con todos desplegados no
        // cabrían en pantalla, así que se recorta a 360px (con los márgenes del popup) y se
        // puede hacer scroll con la rueda del ratón.
        ScrollColumn {
            id: themeList
            maxHeight: 360 - menu.padding * 2
            spacing: 2

            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onReturnPressed: root.apply(root.currentIndex)
            Keys.onEnterPressed: root.apply(root.currentIndex)     // El Intro del teclado numérico
            Keys.onEscapePressed: menu.visible = false

            // Dos secciones, Claros y Oscuros (ver sectionThemes()). "offset": dónde empieza la
            // sección en orderedThemes, para saber el puesto de cada fila
            Repeater {
                model: [{ title: "Claros", themes: root.lightThemes, offset: 0 },
                        { title: "Oscuros", themes: root.darkThemes, offset: root.lightThemes.length }]

                delegate: ColumnLayout {
                    id: section
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.topMargin: index > 0 ? 8 : 0     // Aire antes de la segunda sección
                    spacing: 2

                    SectionTitle {                          // Título de la sección, como en la chuleta de atajos
                        text: Lang.tr(section.modelData.title)
                        font.pixelSize: 11
                        indent: 6
                        spacing: 2
                        Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: section.modelData.themes

                        delegate: HoverRect {
                            id: themeRow
                            required property var modelData
                            required property int index
                            readonly property int position: section.modelData.offset + index     // Su puesto en orderedThemes

                            Layout.fillWidth: true
                            implicitHeight: 30
                            highlighted: position === root.currentIndex
                            onHoveredChanged: if (hovered) { root.followCurrent = false; root.currentIndex = position }
                            // Elegido con las flechas: que se vea. Con el ratón no hace falta (ya está
                            // debajo), y desplazar la lista lo movería y elegiría otra fila
                            onHighlightedChanged: if (highlighted && root.followCurrent) themeList.ensureVisible(themeRow)
                            onClicked: Theme.activeTheme = themeRow.modelData.name
                            border.width: themeRow.modelData.name === Theme.activeTheme ? 1 : 0
                            border.color: Theme.textSelected

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                // Muestra de colores del tema: fondo, acento, rojo, verde y azul
                                Row {
                                    spacing: 2
                                    Repeater {
                                        model: [
                                            themeRow.modelData.base[0],                         // base00: fondo
                                            Theme.accentOf(themeRow.modelData),                 // El acento del tema
                                            themeRow.modelData.base[8],                         // base08: rojo
                                            themeRow.modelData.base[11],                        // base0B: verde
                                            themeRow.modelData.base[13]                         // base0D: azul
                                        ]
                                        delegate: Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 3
                                            color: modelData
                                            border.width: 1
                                            border.color: Theme.border
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: themeRow.modelData.name.replace(/ (Claro|Oscuro)$/, "")   // Sin "Claro"/"Oscuro": ya lo dice la sección ("Ayu Mirage" se queda igual)
                                    color: Theme.textActive
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: themeRow.modelData.name === Theme.activeTheme
                                    text: "✓"
                                    color: Theme.textSelected
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

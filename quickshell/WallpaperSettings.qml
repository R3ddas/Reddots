// Icono en la barra + popup para elegir el fondo de pantalla (Wallpaper.qml).
// Muestra una miniatura de cada imagen de ~/Imágenes/Wallpapers; al pulsar
// una se aplica al momento y queda guardada (Wallpaper.qml persiste la ruta
// sola, igual que Theme.qml con el tema). Las imágenes que se añadan o
// borren de la carpeta aparecen/desaparecen solas, sin reiniciar Quickshell.
import Quickshell
import Quickshell.Widgets           // Para el ClippingRectangle (miniaturas con esquinas redondeadas)
import QtQuick
import QtQuick.Layouts              // Para ColumnLayout y GridLayout
import Qt.labs.folderlistmodel      // Para listar (y vigilar) la carpeta de fondos

ColumnLayout {
    id: root
    spacing: 6

    readonly property int thumbWidth: 140   // Ancho de cada miniatura
    readonly property int thumbHeight: 79   // Alto: 140 * 9/16, proporción 16:9 como la mayoría de monitores

    FolderListModel {
        id: folderModel
        folder: "file://" + Wallpaper.folder                            // Pide una URL, no una ruta
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]    // Solo imágenes que sabe abrir Qt (Background.qml)
        caseSensitive: false                                            // Para que también entren .PNG, .JPG...
        showDirs: false                                                 // Sin subcarpetas
    }

    BarIcon {
        id: iconText
        text: String.fromCodePoint(0xF0E09)  // wallpaper
        tooltip: menu.visible ? "" : "Fondo de pantalla"
        onClicked: menu.toggle()
    }

    BarPopup {
        id: menu
        anchorItem: iconText

        implicitWidth: 2 * (root.thumbWidth + 8) + grid.columnSpacing + 16  // Fijo a 2 columnas, aunque haya un solo fondo
        implicitHeight: Math.min(420, listCol.implicitHeight) + popupCol.spacing + openFolder.implicitHeight + 16  // La lista, como mucho 420px (si hay más fondos se hace scroll), más el botón de abajo

        ColumnLayout {                                      // Lista de fondos arriba y botón "Abrir carpeta" abajo
            id: popupCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Flickable {                                     // Con muchos fondos no caben todos: se recorta y se hace scroll con la rueda (como en ThemeSettings.qml)
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true                     // Ocupa todo lo que deja libre el botón
                clip: true                                  // Oculta las miniaturas que quedan fuera
                contentWidth: width
                contentHeight: listCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds      // Sin rebote al llegar arriba/abajo

                ColumnLayout {
                    id: listCol
                    width: flick.width
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0  // Solo si la carpeta ya se ha leído y está vacía
                        text: "No hay imágenes en\n" + Wallpaper.folder.replace(Quickshell.env("HOME"), "~")
                        color: Theme.textDisabled
                        font.pixelSize: 11
                    }

                    GridLayout {
                        id: grid
                        columns: 2                              // Dos miniaturas por fila
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: folderModel                  // Una celda por imagen de la carpeta

                            delegate: Rectangle {
                                id: cell
                                required property string filePath       // Ruta absoluta (la que se guarda en Wallpaper.path)
                                required property url fileUrl           // La misma ruta como URL, para el Image
                                required property string fileBaseName   // Nombre sin extensión, para el texto de debajo

                                readonly property bool selected: filePath === Wallpaper.path   // Es el fondo activo

                                implicitWidth: root.thumbWidth + 8
                                implicitHeight: cellCol.implicitHeight + 8
                                radius: 6
                                color: cellMouse.containsMouse ? Theme.surfaceHover : "transparent"   // Resalta la celda bajo el ratón

                                ColumnLayout {
                                    id: cellCol
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 3

                                    ClippingRectangle {                // Un Rectangle normal no recorta la imagen con sus esquinas redondeadas
                                        implicitWidth: root.thumbWidth
                                        implicitHeight: root.thumbHeight
                                        radius: 4
                                        color: Theme.background        // Se ve mientras la miniatura carga
                                        contentUnderBorder: true       // El borde se pinta encima: la imagen no encoge al seleccionarla
                                        border.width: cell.selected ? 2 : 1                                 // Más grueso en el fondo activo...
                                        border.color: cell.selected ? Theme.textSelected : Theme.border     // ...y con el color de acento

                                        Image {
                                            anchors.fill: parent
                                            source: cell.fileUrl
                                            fillMode: Image.PreserveAspectCrop         // Rellena la miniatura recortando lo que sobre (como fit_mode = cover)
                                            sourceSize.width: root.thumbWidth * 2      // Se decodifica ya reducida (al doble, para que se vea nítida):
                                            sourceSize.height: root.thumbHeight * 2    // así un fondo 4K no ocupa ~30MB de RAM solo para la miniatura
                                            asynchronous: true                         // No bloquea la barra mientras decodifica
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: cell.fileBaseName
                                        color: cell.selected ? Theme.textSelected : Theme.textActive
                                        font.pixelSize: 10
                                        elide: Text.ElideRight                         // Los nombres largos se cortan con "…"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true                                 // Para el resaltado de la celda
                                    onClicked: Wallpaper.path = cell.filePath          // Wallpaper.qml lo aplica y lo guarda solo
                                }
                            }
                        }
                    }
                }
            }

            MenuRow {                                       // Botón "Abrir carpeta": fuera del Flickable para que se vea siempre, haya los fondos que haya
                id: openFolder
                icon: String.fromCodePoint(0xF0770)         // folder-open
                text: "Abrir carpeta"
                onClicked: {
                    menu.visible = false                                    // Se cierra para no quedar encima de la ventana del explorador
                    Quickshell.execDetached(["xdg-open", Wallpaper.folder]) // Abre el explorador de archivos por defecto (Nemo) en la carpeta de fondos
                }
            }
        }
    }
}

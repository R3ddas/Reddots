pragma Singleton
import Quickshell
import Quickshell.Io                // Para FileView y JsonAdapter
import QtQuick

// Fondo de pantalla activo. Se elige desde el icono de la barra
// (WallpaperSettings.qml) y lo pinta Background.qml, una ventana de Quickshell
// por monitor: basta con cambiar "path" para que se vea (con un fundido) y se
// guarde en wallpaper.json (fuera del repo, junto a theme.json y geometry.json).
Singleton {
    id: root

    // Carpeta de imágenes del usuario (~/Imágenes con el sistema en español), la misma en
    // la que guarda las capturas scripts/screenshot.sh. Se lee de user-dirs.dirs, que es de
    // donde la saca "xdg-user-dir PICTURES"; si no existe, ~/Pictures.
    FileView {
        id: userDirs
        path: Quickshell.env("HOME") + "/.config/user-dirs.dirs"
        blockLoading: true      // Para que text() ya tenga el contenido al calcular "folder"
    }
    readonly property string picturesDir: {
        const m = userDirs.text().match(/^XDG_PICTURES_DIR="(.*)"$/m)     // Línea: XDG_PICTURES_DIR="$HOME/Imágenes"
        return m ? m[1].replace("$HOME", Quickshell.env("HOME")) : Quickshell.env("HOME") + "/Pictures"
    }

    readonly property string folder: picturesDir + "/Wallpapers"    // Carpeta de los fondos (install.sh la enlaza a Wallpapers/ del repo)

    property alias path: adapter.path   // Ruta del fondo activo: al cambiarla (desde WallpaperSettings.qml) se ve y se guarda sola
    // Ya se ha leído wallpaper.json (o se sabe que no existe). Hasta entonces "path" vale el
    // de por defecto, y Background.qml lo pintaría un instante antes del guardado.
    property bool ready: false

    FileView {
        path: Quickshell.statePath("wallpaper.json")    // Fuera del repo, junto a theme.json y geometry.json
        watchChanges: true
        onFileChanged: reload()                         // Si se edita el JSON a mano, se recarga solo
        blockLoading: true                              // Es un archivo diminuto: se lee ya al arrancar
        onAdapterUpdated: writeAdapter()                // Solo salta al cambiar "path", no al cargar el JSON
        onLoadFailed: root.ready = true                 // Aún no existe: se usa el de por defecto
        onLoaded: {
            // Antes los fondos se enlazaban siempre en ~/Pictures/Wallpapers, aunque la carpeta de
            // imágenes fuese otra (~/Imágenes): si la ruta guardada es de ahí, se pasa a la de ahora.
            // Al cambiar "path" salta onAdapterUpdated, que lo guarda.
            const oldFolder = Quickshell.env("HOME") + "/Pictures/Wallpapers/"
            if (root.path.startsWith(oldFolder) && root.folder + "/" !== oldFolder)
                root.path = root.folder + "/" + root.path.slice(oldFolder.length)
            root.ready = true
        }

        JsonAdapter {
            id: adapter
            property string path: root.folder + "/Wallpo1.png"   // Solo si aún no existe wallpaper.json (nunca se ha elegido nada)
        }
    }
}

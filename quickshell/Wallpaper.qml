pragma Singleton
import Quickshell
import Quickshell.Io                // Para FileView y JsonAdapter
import QtQuick

// Fondo de pantalla activo. Se elige desde el icono de la barra
// (WallpaperSettings.qml) y funciona igual que HyprGeometry.qml: el fondo lo
// pinta hyprpaper, no Quickshell, así que no hay binding directo posible.
// Cada cambio se hace en dos sitios:
//   - En caliente, con "hyprctl hyprpaper wallpaper ..." (hyprpaper >= 0.8,
//     ya no hace falta el "preload" de versiones anteriores).
//   - Para el siguiente arranque, regenerando ~/.config/hypr/shellWallpaper.conf
//     (fuera del repo, igual que shellOverrides.lua). hyprland.lua arranca
//     hyprpaper con "-c" apuntando a ese archivo si existe; si no, con el
//     hypr/hyprpaper.conf del repo.
Singleton {
    id: root

    readonly property string folder: Quickshell.env("HOME") + "/Pictures/Wallpapers"                // Carpeta de los fondos (install.sh la enlaza a Wallpapers/ del repo)
    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/shellWallpaper.conf"  // Config de hyprpaper que se genera (fuera del repo, como shellOverrides.lua)

    property alias path: adapter.path   // Ruta del fondo activo: al cambiarla (desde WallpaperSettings.qml) se aplica y se guarda sola

    // Mismo contenido que hypr/hyprpaper.conf pero con la ruta elegida.
    // Se regenera entero cada vez, como overridesText() en HyprGeometry.qml.
    function confText() {
        return "# Generado por Wallpaper.qml (quickshell). No editar a mano: se sobrescribe.\n"
             + "wallpaper {\n"
             + "    monitor =\n"                                        // Vacío = todos los monitores
             + "    path = " + root.path.replace(/#/g, "##") + "\n"     // En hyprlang "#" empieza un comentario, por eso se escapa como "##"
             + "    fit_mode = cover\n"                                 // Rellena la pantalla recortando lo que sobre (igual que en hyprpaper.conf)
             + "}\n"
             + "splash = false\n"                                       // Sin el mensaje de la parte inferior (igual que en hyprpaper.conf)
    }

    FileView {
        path: Quickshell.statePath("wallpaper.json")    // Fuera del repo, junto a theme.json y geometry.json
        watchChanges: true
        onFileChanged: reload()                         // Si se edita el JSON a mano, se recarga solo
        onAdapterUpdated: {                             // Solo salta al cambiar "path", no al cargar el JSON
            writeAdapter()                              // Guarda la ruta en wallpaper.json
            confFile.setText(root.confText())           // Regenera shellWallpaper.conf para el siguiente arranque
            Quickshell.execDetached(["hyprctl", "hyprpaper", "wallpaper", "," + root.path + ",cover"])  // En caliente. Formato "monitor,ruta,modo" (monitor vacío = todos): una ruta con comas fallaría aquí
        }
        // Igual que en HyprGeometry.qml: al arrancar se reescribe el .conf por
        // si se quedó desfasado. Si wallpaper.json no existe todavía (nunca se
        // ha elegido nada) esto no se dispara y hyprpaper sigue con el del repo.
        onLoaded: confFile.setText(root.confText())

        JsonAdapter {
            id: adapter
            property string path: root.folder + "/Wallpo.png"   // Solo si aún no existe wallpaper.json: el mismo de hypr/hyprpaper.conf, para que el selector lo marque
        }
    }

    FileView {                          // Solo se usa para escribir shellWallpaper.conf
        id: confFile
        path: root.confPath
        atomicWrites: true              // Escribe en un temporal y lo renombra: nunca queda un .conf a medias
    }
}

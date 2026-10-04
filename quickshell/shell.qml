//@ pragma IconTheme Papirus
// Recursos: https://tonybtw.com/tutorial/quickshell/

// El pragma de arriba es el tema de iconos de Quickshell (lanzador, notificaciones,
// bandeja). Sin él solo busca en "hicolor" y muchos iconos salían con el genérico o
// no salían. Papirus viene en packages.txt. Tiene que ir en la primera línea del archivo.

import Quickshell
import QtQuick
import Quickshell.Services.Polkit   // Agente de polkit: pide la contraseña cuando una app necesita permisos (windows/PolkitDialog.qml)
import Quickshell.Io                // Para lanzar hypr/scripts/internal-panel.sh
// Las piezas de la interfaz, por carpetas: bar/ (la barra), windows/ (ventanas y capas),
// services/ (singletons con el estado: tema, medidas...) y components/ (piezas comunes)
import qs.bar
import qs.services
import qs.windows

ShellRoot {
    id: root

    // Nombre del panel interno del portátil ("eDP-1"...), "" en un sobremesa. Lo averigua
    // hypr/scripts/internal-panel.sh, el mismo que usa hypr/hyprland.lua.
    property string panelName: ""
    property bool panelKnown: false     // Ya ha respondido el script (hasta entonces no se crea la barra, ver laptopScreen)

    Process {
        running: true
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/internal-panel.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.panelName = text.trim()
                root.panelKnown = true
            }
        }
    }

    // Pantalla del portátil si está presente (con la tapa abierta), si no la primera disponible.
    // Así la barra siempre vive en el portátil en vez de en el monitor que Quickshell elija por defecto.
    // null hasta saber cuál es el panel: si no, en el portátil con un monitor externo la barra
    // podría salir un instante en el externo y luego saltar al portátil.
    readonly property var laptopScreen: {
        if (!panelKnown) return null
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === panelName) return Quickshell.screens[i]
        }
        return Quickshell.screens[0]
    }

    // Agente de polkit (sustituye a hyprpolkitagent). Aquí y no dentro del Variants de
    // abajo: si se destruyese con la pantalla, se daría de baja en el sistema y una
    // petición que llegase justo entonces se quedaría sin respuesta. Solo puede haber
    // un agente por sesión: si hyprpolkitagent sigue en marcha, este no se registra
    // (install.sh lo para y lo desinstala).
    PolkitAgent { id: polkitAgent }

    // Servidor de notificaciones: vive en services/NotificationCenter.qml, fuera del Variants
    // de abajo por lo mismo que el agente de polkit (si no, se perdían las notificaciones al
    // cerrar la tapa). Un singleton no existe hasta que alguien lo usa, y las ventanas que lo
    // usan esperan a saber cuál es la pantalla: nombrarlo aquí lo crea ya al arrancar, para
    // que el sistema no se quede sin servidor ese rato.
    readonly property var notificationCenter: NotificationCenter

    // Fondo de pantalla (windows/Background.qml): en todos los monitores, no solo en el de la
    // barra, así que va en su propio Variants. Se crea y se quita solo al enchufar o
    // desenchufar un monitor (o al cerrar la tapa del portátil).
    Variants {
        model: Quickshell.screens
        Background {
            required property var modelData
            screen: modelData
        }
    }

    // Todas las ventanas van dentro de un Variants: si la pantalla desaparece (monitor
    // apagado, tapa cerrada...) se destruyen, y cuando vuelve se crean de nuevo solas.
    // Sin esto, al volver la pantalla las ventanas no se reenganchaban y la barra
    // desaparecía hasta reiniciar Quickshell.
    Variants {
        model: laptopScreen ? [laptopScreen] : []     // Una sola pantalla (o ninguna mientras no haya)

        Scope {
            id: screenScope
            required property var modelData     // La pantalla en la que se crean las ventanas

            Border {
                screen: screenScope.modelData
                frameColor: Theme.background
            }
            Launcher{screen: screenScope.modelData}    // Widget que se abre/cierra con Super, abajo-derecha
            Notifications{screen: screenScope.modelData}   // Tarjetas emergentes arriba a la derecha (todas, en el popup de SystemStats)
            Osd{screen: screenScope.modelData}         // Indicador de volumen/brillo al usar las teclas multimedia
            Keybinds{id: keybinds; screen: screenScope.modelData}   // Chuleta de atajos, se abre desde el menú de Reddots
            Clipboard{screen: screenScope.modelData}   // Historial del portapapeles, se abre con Super + V
            PolkitDialog{screen: screenScope.modelData; agent: polkitAgent}   // Pide la contraseña cuando una app necesita permisos
            Bar {                                      // La barra lateral (bar/Bar.qml)
                screen: screenScope.modelData
                onKeybindsRequested: keybinds.visible = true
            }
        }
    }
}

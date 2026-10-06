// Lock.qml
// Pantalla de bloqueo: tapa todos los monitores hasta que se escribe la contraseña del
// usuario. Se bloquea con Super + L, desde el menú de apagado de la barra (Power.qml, que
// también bloquea antes de suspender) o con "qs ipc call lock lock" (ver ShellIpc.qml).
//
// Hace además de pantalla de inicio de sesión: el equipo entra solo en la TTY1 (sin
// contraseña, ver "Inicio de sesión" en install.sh) y apps/fish/config.fish crea la marca
// de bloqueo (ver "markerPath") antes de arrancar Hyprland, así que la sesión empieza ya
// bloqueada y la contraseña se pide aquí.
//
// Usa el protocolo de bloqueo de Wayland (ext-session-lock, WlSessionLock): es Hyprland
// quien garantiza que no se ve ni se puede tocar nada de la sesión mientras dure. Si
// Quickshell se cierra o se cae con la pantalla bloqueada, Hyprland la deja bloqueada
// (pintada de un color liso) en vez de abrirla. Para salir de ahí: Ctrl + Alt + F2, entrar
// y lanzar de nuevo Quickshell en la sesión de Hyprland, que vuelve a bloquear sola (ver
// "marker" más abajo y misc.allow_session_lock_restore en hypr/hyprland.lua):
//   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("quickshell")'
//
// Aquí está el estado y la comprobación de la contraseña (con PAM, assets/pam/lock); lo
// que se ve en cada monitor es LockScreen.qml. Va en shell.qml fuera del Variants de la
// pantalla: WlSessionLock ya crea él solo una superficie por monitor, y un bloqueo no
// puede depender de que exista la pantalla de la barra.

import Quickshell
import Quickshell.Io                    // FileView, para la marca de bloqueo
import Quickshell.Wayland                // WlSessionLock
import Quickshell.Services.Pam
import QtQuick
import qs.services

Scope {
    id: root

    readonly property bool locked: sessionLock.locked
    // La contraseña que se está escribiendo. Vive aquí y no en el campo de cada monitor:
    // con varios monitores hay un campo en cada uno (el teclado va al del monitor activo) y
    // así todos muestran lo mismo y da igual en cuál se pulse Intro.
    property string password: ""
    property string message: ""         // Aviso bajo el campo (lo que diga PAM o "Contraseña incorrecta")
    property bool messageIsError: false
    readonly property bool checking: pam.active     // Comprobando la contraseña: el campo no deja escribir
    property int failures: 0            // Cuántas veces se ha fallado; LockScreen.qml sacude la tarjeta cada vez que sube
    property bool suspendPending: false // Hay que suspender en cuanto el bloqueo esté puesto del todo (ver suspend())

    // Marca de "pantalla bloqueada": existe mientras dura el bloqueo. Si Quickshell
    // arranca y la encuentra, bloquea: así empieza bloqueada la sesión (la crea
    // config.fish antes de lanzar Hyprland) y, si Quickshell se reinicia (o se cae) con la
    // pantalla bloqueada, vuelve a bloquear. Si cambias el nombre, cámbialo también en
    // config.fish. Está en XDG_RUNTIME_DIR (/run/user/<uid>), que se vacía al apagar: un
    // bloqueo nunca pasa al siguiente arranque por error.
    readonly property string markerPath: Quickshell.env("XDG_RUNTIME_DIR") + "/reddots-locked"

    function lock() {
        if (sessionLock.locked) return
        password = ""
        message = ""
        messageIsError = false
        sessionLock.locked = true
        Quickshell.execDetached(["touch", markerPath])
    }

    function unlock() {
        sessionLock.locked = false
        password = ""
        Quickshell.execDetached(["rm", "-f", markerPath])
    }

    // Bloquea y suspende. No se suspende a la vez que se bloquea sino cuando Hyprland
    // confirma que todos los monitores están tapados (sessionLock.secure): si no, al
    // despertar se vería el escritorio un instante antes de que apareciese el bloqueo.
    function suspend() {
        suspendPending = true
        if (sessionLock.secure) suspendNow()
        else lock()
    }

    function suspendNow() {
        suspendPending = false
        Quickshell.execDetached(["systemctl", "suspend"])
    }

    // Suspender, reiniciar y apagar desde la pantalla de bloqueo (los botones de
    // LockScreen.qml). Pasan por aquí y no los lanza LockScreen.qml por su cuenta: así quien
    // la crea decide qué hacen; p. ej., para probar su aspecto en una ventana sin que un clic
    // apague el equipo de verdad.
    function power(command) {
        Quickshell.execDetached(command)
    }

    // Intro en el campo. PAM no se arranca hasta tener la contraseña: cuando la pide
    // (onPamMessage), se le da la que ya está escrita.
    function submit() {
        if (pam.active || password === "") return
        message = ""
        pam.start()
    }

    Connections {
        target: ShellIpc
        function onLockRequested() { root.lock() }
        function onSuspendRequested() { root.suspend() }
    }

    FileView {
        path: root.markerPath
        printErrors: false              // Lo normal es que no exista
        blockLoading: true              // Se lee ya al crearse: al inicio de sesión, cuanto antes se bloquee, mejor
        onLoaded: root.lock()           // Solo se lee al arrancar: existe = hay que bloquear (aunque esté vacía)
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("assets/pam")    // El del repo (ver assets/pam/lock)
        config: "lock"

        onPamMessage: {
            if (responseRequired) {
                respond(root.password)
                root.password = ""      // No se queda la contraseña en memoria más de lo necesario
            } else if (message !== "") {
                root.message = message
                root.messageIsError = messageIsError
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock()
                return
            }
            root.failures++
            root.message = result === PamResult.MaxTries ? "Demasiados intentos, espera un poco" : "Contraseña incorrecta"
            root.messageIsError = true
        }

        onError: error => {
            root.message = "No se pudo comprobar la contraseña (" + PamError.toString(error) + ")"
            root.messageIsError = true
        }
    }

    WlSessionLock {
        id: sessionLock
        onSecureChanged: if (secure && root.suspendPending) root.suspendNow()

        // Una por monitor: se crean al bloquear (y al enchufar un monitor con la pantalla
        // bloqueada) y se destruyen al desbloquear
        WlSessionLockSurface {
            color: Theme.background     // Lo que se ve si el fondo de pantalla aún no ha cargado

            LockScreen {
                anchors.fill: parent
                lock: root
            }
        }
    }
}

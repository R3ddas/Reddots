pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Servidor de notificaciones (el que las recibe de las apps por D-Bus) y su estado:
//   - Activas: las que no se han cerrado. Al acabar su tiempo en pantalla no se cierran,
//     solo se ocultan ("caducar = ocultar"): siguen en el popup de SystemStats
//     (bar/settings/SystemStats.qml, lista en bar/settings/NotificationList.qml), con sus botones de
//     acción funcionando, hasta que se descartan a mano. Así no se pierde una que llegó
//     sin estar mirando.
//   - Emergentes ("popups"): las activas que se están enseñando como tarjeta arriba a la
//     derecha (windows/Notifications.qml). Es un subconjunto de las activas.
//   - Historial: copia de las últimas cerradas, solo para leerlas. Del objeto original no
//     queda nada (Quickshell lo destruye al cerrarse), así que no tienen acciones. Solo en
//     memoria: se pierde al reiniciar Quickshell, a propósito (no deja el texto de los
//     mensajes en un archivo).
//
// Está en un singleton y no en las ventanas porque estas van dentro del Variants de la
// pantalla (shell.qml) y se destruyen al cerrar la tapa o cambiar de monitor: con el
// servidor dentro se perdían las notificaciones abiertas, y con el estado dentro las ya
// ocultas volverían a salir. shell.qml lo crea al arrancar (ver allí).
Singleton {
    id: root

    readonly property NotificationServer server: notificationServer
    readonly property var active: notificationServer.trackedNotifications.values   // Las activas, en orden de llegada
    // Hay alguna crítica activa: pone en rojo el icono de SystemStats (y el engranaje plegado), como una temperatura alta
    readonly property bool hasCritical: active.some(n => n.urgency === NotificationUrgency.Critical)
    property var popups: []             // id de las que se enseñan como tarjeta, en orden de llegada
    property var history: []            // Copias de las cerradas, la más reciente primero
    readonly property int maxHistory: 20

    // Hora de llegada de cada activa (id -> ms), para enseñarla en la lista. Quickshell no
    // la guarda. Se rellena antes de que la notificación entre en la lista de activas (ver
    // onNotification), así que ya está cuando se pinta. Si falta, sale sin hora.
    property var arrivals: ({})

    // --- Lo que usan las ventanas ---------------------------------------------

    function isPopup(n) { return popups.includes(n.id) }

    // Se acabó su tiempo en pantalla: deja de ser tarjeta pero sigue activa. Las transitorias
    // (las apps las marcan así para avisos de usar y tirar) sí se dan por caducadas: no
    // pintan nada en la lista ni en el historial.
    function hidePopup(n) {
        if (n.transient) n.expire()
        else popups = popups.filter(id => id !== n.id)       // Reasignar, no modificar: si no, no se entera nadie del cambio
    }

    function showPopup(n) {
        if (!isPopup(n)) popups = popups.concat([n.id])
    }

    function dismissAll() {
        for (const n of active.slice()) n.dismiss()           // Copia de la lista: se va vaciando al cerrarlas
    }

    function dismissPopups() {
        for (const n of active.filter(n => isPopup(n))) n.dismiss()
    }

    function clearHistory() { history = [] }

    // La app la ha sustituido por otra nueva (notify-send -r, Spotify al cambiar de canción...):
    // Quickshell reutiliza el mismo objeto y no avisa con onNotification, así que si ya estaba
    // oculta no se vería el cambio. Se vuelve a enseñar como tarjeta y cuenta como recién llegada.
    function replaced(n) {
        arrivals[n.id] = Date.now()
        arrivalsChanged()                                    // arrivals se modifica por dentro: hay que avisar a mano
        showPopup(n)
    }

    function removeFromHistory(entry) { history = history.filter(e => e !== entry) }

    // --- Avisos propios ----------------------------------------------------------

    // Manda una notificación de la propia interfaz (batería baja, Bluetooth, wifi...). Con
    // notify-send y no directamente: Quickshell no deja crear notificaciones desde QML, solo
    // recibirlas. Llega a este mismo servidor como la de cualquier app.
    //   app: nombre que sale en la notificación · icon: icono del tema ("" = ninguno)
    //   urgency: "low", "normal" o "critical"
    function notify(app, icon, summary, body, urgency = "normal") {
        Quickshell.execDetached(["notify-send", "-u", urgency, "-a", app]
            .concat(icon ? ["-i", icon] : [], [summary, body]))
    }

    // --- Servidor --------------------------------------------------------------

    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodySupported: true
        imageSupported: true    // Sin esto, algunas apps (Teams, Chrome...) no mandan la imagen (avatar, foto) aunque la tengan

        onNotification: n => {
            root.arrivals[n.id] = Date.now()
            root.showPopup(n)
            n.tracked = true     // Se queda en la lista (activa) hasta que se cierra
        }
    }

    // Un Connections por cada activa. Va así, siguiendo la lista, y no conectando las
    // señales en onNotification, para que también valga con las que Quickshell conserva
    // al recargar la configuración (esas no vuelven a pasar por onNotification).
    Instantiator {
        model: notificationServer.trackedNotifications
        delegate: Connections {
            id: conn
            required property var modelData
            target: modelData

            // Se cierra (descartada a mano, caducada o retirada por la propia app): se
            // copia al historial. Quickshell avisa antes de destruirla, así que aún se
            // puede leer. Las transitorias no se guardan.
            function onClosed(reason) {
                const n = conn.modelData
                root.popups = root.popups.filter(id => id !== n.id)
                const time = root.arrivals[n.id] ?? 0
                delete root.arrivals[n.id]
                if (n.transient) return
                root.history = [{
                    appName: n.appName,
                    appIcon: n.appIcon,
                    desktopEntry: n.desktopEntry,
                    image: n.image,
                    summary: n.summary,
                    body: n.body,
                    critical: n.urgency === NotificationUrgency.Critical,
                    time: time
                }].concat(root.history).slice(0, root.maxHistory)
            }

            // Cambia el texto: la app la ha sustituido por otra (ver replaced())
            function onSummaryChanged() { root.replaced(conn.modelData) }
            function onBodyChanged() { root.replaced(conn.modelData) }
        }
    }
}

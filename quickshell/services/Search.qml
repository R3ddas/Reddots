pragma Singleton
import Quickshell
import QtQuick

// Ayudas para los buscadores (Launcher.qml y Clipboard.qml).
Singleton {
    // Quita mayúsculas y tildes, para que "musica" encuentre "Música"
    function normalize(s) {
        return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    }
}

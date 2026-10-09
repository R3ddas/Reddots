// JSON con estado de la interfaz que se guarda solo: el tema, el fondo, las medidas, el uso
// de las apps del lanzador... Vive en el directorio de estado de Quickshell
// (~/.local/state/quickshell), fuera del repo, así que sobrevive a reiniciar Quickshell.
// Quien lo usa le da el nombre del archivo y pone dentro un JsonAdapter con las
// propiedades: al cambiar una se guarda el archivo, y si se edita a mano se recarga solo.
// Si necesita hacer algo más al cargar o al cambiar, puede poner su propio onLoaded,
// onAdapterUpdated... (se ejecutan los dos: el de aquí y el suyo).
import Quickshell
import Quickshell.Io
import QtQuick

FileView {
    required property string name       // "theme.json"...

    path: Quickshell.statePath(name)
    watchChanges: true
    onFileChanged: reload()             // Si se edita el JSON a mano, se recarga solo
    onAdapterUpdated: writeAdapter()    // Solo salta al cambiar una propiedad, no al cargar el JSON
}

pragma Singleton
import Quickshell
import Quickshell.Io                // FileView y JsonAdapter
import QtQuick

// Tema "Wallpaper": un tema Base16 (16 colores, como todos los de themes.js) sacado del
// fondo de pantalla activo. Se crea desde el selector de tema (ThemeSettings.qml) con
// generate(); al crearlo de nuevo a partir de otro fondo, se sobrescribe: solo hay uno.
//
// Se guarda en wallpaperTheme.json, en el directorio de estado de Quickshell (junto a
// theme.json y wallpaper.json) y no en themes.js: themes.js es del repo, y reescribirlo
// dejaría un cambio local que haría fallar las actualizaciones (git merge --ff-only en
// scripts/update-reddots.sh) en cuanto una de ellas tocase ese archivo. Theme.qml lo añade
// a su lista de temas al cargar ("themes"), así que en el selector sale como uno más.
//
// Cómo se sacan los colores (todo en OKLCH, donde la luminosidad L se percibe igual en
// todos los tonos y se puede fijar para que el texto se lea):
//   - ColorQuantizer reduce la imagen a 16 colores que ocupan, cada uno, más o menos la
//     misma parte de la imagen. Su luminosidad media dice si el tema es claro u oscuro.
//   - base00–07 (del fondo al texto): grises con una luminosidad fija (la de los temas
//     claros u oscuros de themes.js), teñidos con el tono medio de la imagen.
//   - base08–0E (rojo, naranja, amarillo, verde, cian, azul, morado): cada uno en su tono
//     de siempre, para que en la terminal el verde siga siendo verde (el mismo criterio que
//     los temas de Caelestia en themes.js). Si la imagen tiene un color vivo cerca de ese
//     tono, la casilla toma su saturación y se acerca algo a su tono. Luminosidad fija,
//     para que se lean sobre el fondo. base0F (marrón): un naranja oscuro y apagado.
//   - Acento: la casilla del color más vivo de la imagen. Nunca el rojo (base08), que
//     queda para errores y avisos, como en el resto de temas; sin colores vivos (una
//     imagen en grises), el azul (base0D), el acento de casi todos los temas.
Singleton {
    id: root

    readonly property string themeName: "Wallpaper"

    // El tema guardado, con la forma de los de themes.js ({ name, accent, base }), o null si
    // aún no se ha creado. Cambia (y con él Theme.themes) cada vez que se crea de nuevo.
    readonly property var theme: adapter.base.length === 16
        ? { name: themeName, accent: adapter.accent, base: adapter.base }
        : null
    readonly property string source: adapter.source     // Fondo del que salió (ruta), para saber si ya está al día
    property bool generating: false                     // Esperando a que ColorQuantizer termine

    signal generated()                                  // Ya está guardado el tema nuevo

    // Un FileView normal y no StateFile: StateFile guarda en cuanto cambia una propiedad y
    // vigila el archivo para releerlo; al guardar los colores y luego el acento, la relectura
    // del primer guardado devolvía el acento anterior y pisaba el nuevo. Aquí se cambian
    // las tres propiedades y se guarda una sola vez (ver build()).
    FileView {
        id: stateFile
        path: Quickshell.statePath("wallpaperTheme.json")     // Junto a theme.json (StateFile)
        // Se lee ya al crearse: Theme.qml lo necesita en su lista antes de aplicar el tema
        // guardado al arrancar (si el activo es "Wallpaper" y aún no estuviese, aplicaría
        // el de por defecto, Theme.defaultTheme, a Alacritty y a Hyprland)
        blockLoading: true
        printErrors: false              // Lo normal es que no exista hasta que se cree

        JsonAdapter {
            id: adapter
            property list<string> base: []
            property string accent: "base0D"
            property string source: ""
        }
    }

    // Crea el tema a partir del fondo activo (Wallpaper.path) y lo guarda. Es asíncrono:
    // avisa con generated().
    function generate() {
        if (!Wallpaper.path) return
        generating = true
        // Si ya se cuantizó este fondo (otra vez el mismo), los colores ya están: no hay
        // onColorsChanged que esperar
        if (quantizedPath === Wallpaper.path && quantizer.colors.length > 0) build()
        else {
            quantizedPath = Wallpaper.path
            quantizer.source = "file://" + Wallpaper.path
        }
    }
    property string quantizedPath: ""   // Fondo que tiene cargado el ColorQuantizer (su "source" es una URL, que puede venir codificada)

    ColorQuantizer {
        id: quantizer
        depth: 4                        // 2^4 = 16 colores
        rescaleSize: 128                // Se reduce la imagen antes: para la paleta sobra, y es mucho más rápido
        onColorsChanged: if (root.generating && colors.length > 0) root.build()
    }

    function build() {
        const palette = Array.from(quantizer.colors).map(c => oklch(c))
        const t = makeTheme(palette)
        adapter.base = t.base
        adapter.accent = t.accent
        adapter.source = quantizedPath         // El fondo del que salen los colores (por si Wallpaper.path ha cambiado mientras tanto)
        stateFile.writeAdapter()
        generating = false
        generated()
    }

    // --- El tema a partir de la paleta ----------------------------------------------------

    // Luminosidad (L de OKLCH) de los grises base00–07. Salen de los temas de themes.js:
    // fondos de 0,2–0,3 en los oscuros y de 0,93–0,97 en los claros, y el texto (base05) con
    // contraste de sobra en los dos.
    readonly property var darkRamp:  [0.22, 0.27, 0.33, 0.48, 0.62, 0.86, 0.91, 0.95]
    readonly property var lightRamp: [0.97, 0.93, 0.87, 0.68, 0.55, 0.33, 0.27, 0.21]

    // Tono (grados de OKLCH) de cada casilla de color, base08–0E: los de rojo, naranja,
    // amarillo, verde, cian, azul y morado puros
    readonly property var accentHues: [29, 55, 100, 145, 195, 260, 310]

    function makeTheme(palette) {
        const light = palette.reduce((s, c) => s + c.l, 0) / palette.length > 0.6
        const ramp = light ? lightRamp : darkRamp

        // Tinte de los grises: el tono medio de la imagen (media en a/b de OKLab, así los
        // colores opuestos se compensan) y su saturación, tope 0,035 para que sigan siendo grises
        const a = palette.reduce((s, c) => s + c.c * Math.cos(c.h * Math.PI / 180), 0) / palette.length
        const b = palette.reduce((s, c) => s + c.c * Math.sin(c.h * Math.PI / 180), 0) / palette.length
        const tintHue = Math.atan2(b, a) * 180 / Math.PI
        const tintChroma = Math.min(Math.hypot(a, b), 0.035)
        // El texto (base05–07), con la mitad de tinte: casi neutro, se lee mejor
        const grays = ramp.map((l, i) => hex(l, i >= 5 ? tintChroma / 2 : tintChroma, tintHue))

        // Colores vivos de la imagen (saturación > 0,05): los que pueden dar carácter a las casillas
        const vivid = palette.filter(c => c.c > 0.05)
        // Saturación mínima de las casillas: la del color más vivo de la imagen, acotada, así
        // un fondo apagado da un tema más apagado que uno vivo. Nunca por debajo de 0,09:
        // con menos, el rojo y el naranja (o el verde y el cian) ya no se distinguían.
        const maxChroma = vivid.reduce((m, c) => Math.max(m, c.c), 0)
        const baseChroma = Math.max(0.09, Math.min(maxChroma, 0.13))

        // Cada color vivo de la imagen cuenta solo para la casilla de tono más cercano. Si
        // contase para todas las que tiene a menos de 30°, un mismo color tiraba a la vez del
        // rojo y del naranja (sus tonos están a 26°) y los dos acababan casi iguales.
        const nearestSlot = c => accentHues.reduce((best, h, i) =>
            Math.abs(hueDiff(c.h, h)) < Math.abs(hueDiff(c.h, accentHues[best])) ? i : best, 0)

        const accentL = light ? 0.55 : 0.72     // Luminosidad de los colores: legibles sobre el fondo
        const slots = accentHues.map((target, i) => {
            // El rojo (base08) es el de los errores y avisos: siempre rojo puro y bien
            // saturado, para que no se confunda con el naranja ni pase desapercibido
            if (i === 0) return { hue: target, chroma: Math.max(baseChroma, 0.14), source: null }
            // El color vivo de la imagen más saturado de esta casilla, si está a menos de 30°
            const near = vivid.filter(c => nearestSlot(c) === i && Math.abs(hueDiff(c.h, target)) < 30)
                              .reduce((best, c) => !best || c.c > best.c ? c : best, null)
            if (!near) return { hue: target, chroma: baseChroma, source: null }
            return {
                // Se acerca al tono de la imagen como mucho 8°, para que cada casilla siga
                // siendo su color y no se junte con la de al lado
                hue: target + Math.max(-8, Math.min(8, hueDiff(near.h, target))),
                // La imagen solo sube la saturación (hasta 0,17), nunca la baja de baseChroma
                chroma: Math.max(baseChroma, Math.min(near.c, 0.17)),
                source: near
            }
        })
        const accents = slots.map(s => hex(accentL, s.chroma, s.hue))
        // Marrón (base0F): el tono del naranja, más oscuro y apagado
        const brown = hex(light ? 0.45 : 0.58, 0.07, slots[1].hue)

        // Acento: la casilla cuyo color de la imagen sea el más vivo (el rojo nunca lo es: no
        // toma color de la imagen, ver arriba)
        let accentIndex = 5                     // base0D, el azul
        let best = 0
        for (let i = 0; i < slots.length; i++) {
            if (slots[i].source && slots[i].source.c > best) {
                best = slots[i].source.c
                accentIndex = i
            }
        }

        return {
            base: grays.concat(accents, [brown]),
            accent: "base0" + (8 + accentIndex).toString(16).toUpperCase()     // 8 + 5 -> "base0D"
        }
    }

    // Cuánto está el tono "a" del tono "b", entre -180 y 180 grados (por el camino corto)
    function hueDiff(a, b) {
        return ((a - b + 540) % 360) - 180
    }

    // --- Conversión de color (OKLab/OKLCH, https://bottosson.github.io/posts/oklab/) --------

    // QML color -> { l, c, h } (h en grados)
    function oklch(color) {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        const r = lin(color.r), g = lin(color.g), b = lin(color.b)
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        const L  = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        const A  = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        const B  = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        return { l: L, c: Math.hypot(A, B), h: (Math.atan2(B, A) * 180 / Math.PI + 360) % 360 }
    }

    // OKLCH -> sRGB lineal [r, g, b] (puede salirse de 0–1 si el color no cabe en sRGB)
    function linearRgb(L, C, h) {
        const A = C * Math.cos(h * Math.PI / 180), B = C * Math.sin(h * Math.PI / 180)
        const l = Math.pow(L + 0.3963377774 * A + 0.2158037573 * B, 3)
        const m = Math.pow(L - 0.1055613458 * A - 0.0638541728 * B, 3)
        const s = Math.pow(L - 0.0894841775 * A - 1.2914855480 * B, 3)
        return [ 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s]
    }

    // OKLCH -> "#rrggbb". Si el color no cabe en sRGB (demasiado saturado para esa
    // luminosidad), se le baja la saturación hasta que quepa, sin tocar el tono ni la luminosidad
    function hex(L, C, h) {
        const fits = rgb => rgb.every(v => v >= -0.0001 && v <= 1.0001)
        let lo = 0, hi = C
        if (!fits(linearRgb(L, C, h))) {
            for (let i = 0; i < 20; i++) {          // Búsqueda binaria de la saturación máxima que cabe
                const mid = (lo + hi) / 2
                if (fits(linearRgb(L, mid, h))) lo = mid
                else hi = mid
            }
            C = lo
        }
        const gamma = v => v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055
        return "#" + linearRgb(L, C, h)
            .map(v => Math.round(Math.max(0, Math.min(1, gamma(v))) * 255).toString(16).padStart(2, "0"))
            .join("")
    }
}

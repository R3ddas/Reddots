-- Config principal de Hyprland (API Lua). Está repartida en varios archivos que
-- se cargan con require(): keybinds.lua, programs.lua (desde keybinds.lua) y los
-- que genera Quickshell fuera del repo (ver requireIfExists, más abajo).


-------------------
---- MONITORES ----
-------------------

-- Ver https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Nada de nombres de máquina ni de conector: valen igual en el portátil y en el sobremesa.
local monitors = require("monitors")

-- Cualquier monitor: su resolución más alta y, dentro de esa, la mayor frecuencia
-- ("highres"). Así cada monitor va a su resolución nativa a máximo refresco sin
-- escribir su modo a mano ("preferred" dejaba el MSI del sobremesa a 60Hz en vez
-- de a 165Hz). "auto" coloca cada monitor a la derecha de los que ya hay.
hl.monitor({
    output   = "",
    mode     = "highres",
    position = "auto",
    scale    = "1",
})

-- El panel del portátil, si lo hay, siempre a la izquierda (0x0), con los externos a
-- su derecha. También cuando hypr/scripts/lid-watcher.sh lo apaga y lo vuelve a
-- encender al cerrar/abrir la tapa (allí se reactiva con estos mismos valores).
local internalPanel = monitors.internalPanel()
if internalPanel then
    hl.monitor({
        output   = internalPanel,
        mode     = "highres",
        position = "0x0",
        scale    = "1",
    })
end


----------------------
---- AUTOARRANQUE ----
----------------------

-- Ver https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function ()
    hl.exec_cmd("quickshell")

    -- El gestor del fondo de pantalla. Si ya se ha elegido un fondo desde la
    -- barra (quickshell/WallpaperSettings.qml), arranca con la config que
    -- genera quickshell/Wallpaper.qml; si no, con hypr/hyprpaper.conf.
    local wallpaperConf = os.getenv("HOME") .. "/.config/hypr/shellWallpaper.conf"   -- Fuera del repo, lo genera Wallpaper.qml (igual que shellOverrides.lua)
    local wallpaperConfFile = io.open(wallpaperConf, "r")   -- Lua no tiene un "exists": se intenta abrir para saber si existe
    if wallpaperConfFile then
        wallpaperConfFile:close()
        hl.exec_cmd('hyprpaper -c "' .. wallpaperConf .. '"')   -- Con el fondo elegido en la barra (entre comillas por si la ruta tiene espacios)
    else
        hl.exec_cmd("hyprpaper")                                -- Todavía no se ha elegido nada: usa hypr/hyprpaper.conf
    end

    hl.exec_cmd("systemctl --user start hyprpolkitagent")   -- Necesario para autorizar montar discos, etc. (No me gusta mucho)
    hl.exec_cmd("bash ~/.config/hypr/scripts/lid-watcher.sh")  -- Apaga el panel del portátil al cerrar la tapa
    hl.exec_cmd("wl-paste --watch cliphist store")             -- Guarda en el historial todo lo que se copia (texto e imágenes); se ve con Super + V (quickshell/Clipboard.qml)
end)

------------------------------
---- VARIABLES DE ENTORNO ----
------------------------------

-- Ver https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------
---- ASPECTO ----
-----------------

-- Ver https://wiki.hypr.land/Configuring/Basics/Variables/
local opacity = 0.9
hl.config({
    general = {
        -- gaps_in, gaps_out y border_size de aquí son solo el valor de
        -- ARRANQUE (para una instalación nueva, antes de tocar nada).
        -- En cuanto se cambia algo en el panel GeometrySettings.qml de
        -- Quickshell, HyprGeometry.qml los aplica en caliente (hyprctl eval)
        -- y los guarda en hypr/shellOverrides.lua (ver el require() al final
        -- de este hl.config, más abajo), que gana siempre a estos valores. Editar
        -- estas líneas a mano no tiene efecto una vez que existe ese archivo.
        gaps_in  = 5,       -- Distancia entre ventanas
        gaps_out = 12,      -- Distancia entre ventana y borde de pantalla
        border_size = 2,    -- Grosor del borde de cada ventana

        -- Igual que lo de arriba, solo el valor de ARRANQUE: en cuanto Quickshell
        -- arranca, Theme.qml los sobrescribe con los del tema elegido vía
        -- hypr/shellTheme.lua (ver el require() más abajo). Son los del tema
        -- "Gruvbox Claro", el que usa Theme.qml por defecto.
        col = {
            active_border   = { colors = {0xeeaf3a03, 0xee3c3836}, angle = 45 },   -- Degradado textSelected -> textActive
            inactive_border = 0xaabdae93,                                          -- border
        },

        resize_on_border = false, -- A true permite redimensionar las ventanas arrastrando sus bordes y los huecos entre ellas
        allow_tearing = false,    -- Antes de activarlo, ver https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/

        -- Colocación automática de ventanas
        -- dwindle: cada vez que abrís una ventana nueva, divide el espacio de la última ventana enfocada en dos (alternando entre división horizontal y vertical)
        -- master: mantiene una ventana "maestra" grande a un lado y apila el resto en una columna secundaria.
        layout = "dwindle",
    },

    decoration = {
        rounding       = 16, -- Igual que gaps_in/gaps_out/border_size arriba: solo el valor de arranque, sobrescrito por el panel/shellOverrides.lua
        rounding_power = 2,

        -- Transparencia de las ventanas
        active_opacity   = opacity,     -- Opacidad de la ventana activa
        inactive_opacity = opacity,     -- Opacidad de las ventanas inactivas
        fullscreen_opacity = opacity,   -- Opacidad de las ventanas en pantalla completa (las de la regla "opaque-media" van siempre opacas)

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Archivos que genera Quickshell en ~/.config/hypr (fuera del repo) para
-- sobrescribir en caliente parte de lo de arriba. No existen hasta que
-- Quickshell los escribe por primera vez; en cuanto se crean, Hyprland los
-- deja bajo watch (por el require) y los recarga solo en cambios sucesivos,
-- sin que haga falta este chequeo otra vez.
local function requireIfExists(name)
    local file = io.open(os.getenv("HOME") .. "/.config/hypr/" .. name .. ".lua", "r")  -- Lua no tiene un "exists": se intenta abrir para saber si existe
    if file then
        file:close()
        require(name)
    end
end

requireIfExists("shellOverrides")   -- gaps_in/gaps_out/border_size (general) y rounding (decoration), desde el panel GeometrySettings.qml (quickshell/HyprGeometry.qml)
requireIfExists("shellTheme")       -- col.active_border/inactive_border (general), según el tema elegido (quickshell/Theme.qml)

-- Curvas y animaciones por defecto, ver https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Muelles (springs) por defecto
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })


-- Ver https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
hl.config({
    dwindle = {
        preserve_split = true, -- Mantiene la orientación de cada división (horizontal/vertical) aunque cambie el tamaño de las ventanas
    },
})

-- Ver https://wiki.hypr.land/Configuring/Layouts/Master-Layout/
hl.config({
    master = {
        new_status = "master",
    },
})

-- Ver https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

--------------------
---- MISCELÁNEA ----
--------------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- 0 o 1 quita los fondos por defecto de la mascota anime
        disable_hyprland_logo   = true, -- Quita el logo de Hyprland / la chica anime del fondo
        disable_splash_rendering = true,
        -- Si se nota parpadeo en juegos o vídeos, cambiar el 2 por un 3: solo se activa
        -- cuando la aplicación indica que lo que muestra es un juego o un vídeo.
        vrr = 2,                       -- VRR (FreeSync) solo con una ventana en pantalla completa: juegos y vídeos sin tirones, el escritorio a frecuencia fija
    },
})


-----------------
---- ENTRADA ----
-----------------

hl.config({
    input = {
        kb_layout  = "es",              -- Teclado en espannol
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",
        numlock_by_default = true,      -- Bloq num activo por defecto

        follow_mouse = 1,
        sensitivity = 0, -- De -1.0 a 1.0; 0 = sin modificar
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({                            -- Puedo cambiar entre workspaces con 3 dedos
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

---------------------------
---- ATAJOS DE TECLADO ----
---------------------------
require("keybinds")


-------------------------------
---- VENTANAS Y WORKSPACES ----
-------------------------------

-- Ver https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- y https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
    -- Ignora las peticiones de maximizar de todas las apps (así no se salen del mosaico)
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Arregla algunos problemas al arrastrar en apps XWayland (ventanas flotantes sin clase ni título)
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Imágenes, vídeos y juegos de Steam siempre opacos, con o sin pantalla completa
-- (el resto de ventanas usa la transparencia de "opacity", ver ASPECTO)
hl.window_rule({
    name  = "opaque-media",
    match = { class = "^(imv|mpv|steam_app_.*)$" },    -- Los juegos de Steam tienen clase "steam_app_<número>"

    opaque = true,
})

-- La ventanita de hyprland-run, flotante y abajo a la izquierda
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Hago que los diálogos "Open with" aparezcan flotantes y centrado, si no, se cortan y no se puede acceder a los campos
hl.window_rule({
    name  = "center-open-with",
    match = {title = "^Open with.*" },
    float  = true,
    center = true,
})

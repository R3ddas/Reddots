-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Regla genérica primero, como red de seguridad para cualquier monitor que
-- no tenga una regla específica más abajo (otra máquina, otro monitor externo, etc).
-- Las reglas posteriores para un mismo monitor sustituyen a esta.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-- Reglas explícitas para este portátil: así el externo mantiene siempre su
-- resolución nativa a máximo refresco, incluso cuando
-- hypr/scripts/lid-watcher.sh reaplica la config al abrir/cerrar la tapa.
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
    --mirror   = "eDP-1" Esto igual se puede guardar como variable de entorno
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "2560x1440@143.85",  -- Resolución nativa a máximo refresco (soporta hasta 143.85Hz)
    position = "1920x0",
    scale    = "1",
})



---------------------
---- MY PROGRAMS ----
---------------------
local programs = require("programs")
local terminal, fileManager, menu = programs.terminal, programs.fileManager, programs.menu


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
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
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
local opacity = 0.9
hl.config({
    general = {
        -- gaps_in, gaps_out y border_size de aquí son solo el valor de
        -- ARRANQUE (para una instalación nueva, antes de tocar nada).
        -- En cuanto se cambia algo en el panel GeometrySettings.qml de
        -- Quickshell, HyprGeometry.qml los sobrescribe en caliente vía
        -- hypr/shellOverrides.lua (ver el require() al final de este
        -- hl.config, más abajo), que gana siempre a estos valores. Editar
        -- estas líneas a mano no tiene efecto una vez que existe ese archivo.
        gaps_in  = 5,       -- Distancia entre ventanas
        gaps_out = 12,      -- Distancia entre ventana y borde de pantalla
        border_size = 2,    -- Grosor del borde de cada ventana

        -- Igual que lo de arriba, solo el valor de ARRANQUE: en cuanto Quickshell
        -- arranca, Theme.qml los sobrescribe con los del tema elegido vía
        -- hypr/shellTheme.lua (ver el require() más abajo). Son los del tema "Original".
        col = {
            active_border   = { colors = {0xeedb911a, 0xeef5e2c5}, angle = 45 },   -- Degradado textSelected -> textActive
            inactive_border = 0xaa5a4d3e,                                          -- border
        },

        resize_on_border = false, -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        allow_tearing = false,    -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on

        -- Colocación automática de ventanas
        -- dwindle: cada vez que abrís una ventana nueva, divide el espacio de la última ventana enfocada en dos (alternando entre división horizontal y vertical)
        -- master: mantiene una ventana "maestra" grande a un lado y apila el resto en una columna secundaria.
        layout = "dwindle",
    },

    
    decoration = {
        rounding       = 16, -- Igual que gaps_in/gaps_out/border_size arriba: solo el valor de arranque, sobrescrito por el panel/shellOverrides.lua
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = opacity,     -- Opacidad de la ventana activa
        inactive_opacity = opacity,     -- Opacidad de las ventanas inactivas
        fullscreen_opacity = opacity,   -- Opacidad de las ventanas en pantalla completa

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

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
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


-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
        disable_splash_rendering = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "es",              -- Teclado en espannol
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",
        numlock_by_default = true,      -- Bloq num activo por defecto

        follow_mouse = 1,
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
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

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------
require("keybinds")


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

    -- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
    -- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

    -- Example window rules that are useful

    local suppressMaximizeRule = hl.window_rule({
        -- Ignore maximize requests from all apps. You'll probably like this.
        name  = "suppress-maximize-events",
        match = { class = ".*" },

        suppress_event = "maximize",
    })
    -- suppressMaximizeRule:set_enabled(false)

    hl.window_rule({
        -- Fix some dragging issues with XWayland
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

    -- Layer rules also return a handle.
    -- local overlayLayerRule = hl.layer_rule({
    --     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
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

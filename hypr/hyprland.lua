-- Config principal de Hyprland (API Lua). Está repartida en varios archivos que
-- se cargan con require(): monitors.lua (desde aquí y desde keybinds.lua), keybinds.lua,
-- programs.lua (desde keybinds.lua) y los que genera Quickshell fuera del repo (ver
-- requireIfExists, más abajo).


-------------------
---- MONITORES ----
-------------------

-- Ver https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Nada de nombres de máquina ni de conector: valen igual en el portátil y en el sobremesa.
local monitors = require("monitors")

-- Cualquier monitor: de entrada su resolución nativa ("preferred", la que el monitor
-- marca como suya). "auto" coloca cada monitor a la derecha de los que ya hay.
-- No vale "highres" (la resolución más alta): el MSI anuncia 3840x2160 aunque su panel
-- es de 2560x1440, y así se veía borroso (lo reescalaba él) y todo diminuto.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-- El panel del portátil, si lo hay, siempre a la izquierda (0x0), con los externos a
-- su derecha. También cuando se vuelve a encender al abrir la tapa (ver más abajo).
local internalPanel = monitors.internalPanel()
local panelRule = {
    output   = internalPanel,
    disabled = false,       -- Explícito: si no, al reaplicar la regla se conserva el "disabled = true" de cerrar la tapa
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
}
if internalPanel then
    hl.monitor(panelRule)
end

-- "preferred" suele venir a 60Hz (el MSI se quedaba a 60 en vez de a 144/165Hz), así
-- que en cuanto aparece cada monitor se sube a la mayor frecuencia que admita en esa
-- misma resolución nativa. Solo se toca si no está ya así, para no repetir el cambio.
local function bestModes()
    for _, mon in ipairs(hl.get_monitors()) do     -- Solo los activos (no el panel con la tapa cerrada)
        local native, best
        for _, mode in ipairs(mon.available_modes) do
            if mode.preferred then native = mode end
        end
        for _, mode in ipairs(mon.available_modes) do
            if native and mode.width == native.width and mode.height == native.height
                and (not best or mode.refresh_rate > best.refresh_rate) then
                best = mode
            end
        end
        if best and (mon.width ~= best.width or mon.height ~= best.height
                     or math.abs(mon.refresh_rate - best.refresh_rate) > 0.5) then
            hl.monitor({
                output   = mon.name,
                mode     = string.format("%dx%d@%.3f", best.width, best.height, best.refresh_rate),
                position = mon.name == internalPanel and "0x0" or "auto",
                scale    = "1",
            })
        end
    end
end
local function bestModesSoon()      -- En diferido, por lo mismo que applyLidSoon (más abajo)
    hl.timer(bestModes, { timeout = 200, type = "oneshot" })
end
hl.on("monitor.added",   bestModesSoon)
hl.on("config.reloaded", bestModesSoon)
hl.on("hyprland.start",  bestModesSoon)

-- Tapa del portátil. Al cerrarla, si hay un monitor externo, el panel se desactiva y
-- el externo se queda como único monitor (ventanas, workspaces y barra pasan a él).
-- Sin monitor externo el panel solo se apaga (DPMS) y la sesión sigue igual.
-- Al abrirla vuelve a como estaba.
--
-- Se usa el evento de la tapa del propio Hyprland ("switch:on/off:Lid Switch", de
-- libinput) y no la señal PropertiesChanged de logind, que no llegaba de forma fiable.
-- Además se vuelve a aplicar al enchufar/desenchufar un monitor con la tapa cerrada
-- y tras recargar la config (la recarga vuelve a poner la regla del panel, encendido).
if internalPanel then
    local function logindLidClosed()     -- Solo para el estado inicial; luego manda el evento
        local out = io.popen("busctl get-property org.freedesktop.login1 /org/freedesktop/login1"
            .. " org.freedesktop.login1.Manager LidClosed 2>/dev/null")
        if not out then return false end
        local answer = out:read("a") or ""
        out:close()
        return answer:find("true") ~= nil
    end
    local lidClosed = logindLidClosed()

    local function applyLid()
        local panelOn, hasExternal = false, false
        for _, mon in ipairs(hl.get_monitors()) do     -- Solo lista los monitores activos
            if mon.name == internalPanel then panelOn = true else hasExternal = true end
        end

        if lidClosed and hasExternal then
            if panelOn then hl.monitor({ output = internalPanel, disabled = true }) end
        else
            if not panelOn then hl.monitor(panelRule) end
            hl.dispatch(hl.dsp.dpms({ action = lidClosed and "off" or "on", monitor = internalPanel }))
        end
    end

    -- En diferido: se llama desde eventos de monitores y aplicar reglas ahí dentro
    -- volvería a disparar esos mismos eventos
    local function applyLidSoon()
        hl.timer(applyLid, { timeout = 200, type = "oneshot" })
    end

    hl.bind("switch:on:Lid Switch",  function() lidClosed = true;  applyLid() end, { locked = true })
    hl.bind("switch:off:Lid Switch", function() lidClosed = false; applyLid() end, { locked = true })
    hl.on("monitor.added",   applyLidSoon)
    hl.on("monitor.removed", applyLidSoon)
    hl.on("config.reloaded", applyLidSoon)
    hl.on("hyprland.start",  applyLidSoon)     -- Por si Hyprland arranca con la tapa ya cerrada
end


----------------------
---- AUTOARRANQUE ----
----------------------

-- Ver https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function ()
    hl.exec_cmd("quickshell")   -- La barra, las ventanas de la shell, el agente de polkit y el fondo de pantalla (quickshell/Background.qml)

    hl.exec_cmd("wl-paste --watch cliphist store")             -- Guarda en el historial todo lo que se copia (texto e imágenes); se ve con Super + V (quickshell/Clipboard.qml)

    -- Al cerrar la tapa manda Hyprland (ver MONITORES), no logind: sin esto, sin monitor
    -- externo logind suspendería el portátil (HandleLidSwitch=suspend). El bloqueo dura
    -- lo que dure el "sleep", es decir, toda la sesión. No pide contraseña.
    if internalPanel then
        hl.exec_cmd("systemd-inhibit --what=handle-lid-switch --mode=block --who=Reddots"
            .. " --why='Hyprland apaga el panel al cerrar la tapa' sleep infinity")
    end
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
-- Como gaps_in/gaps_out/border_size más abajo, solo el valor de ARRANQUE: el
-- panel GeometrySettings.qml ("Opacidad de ventanas") lo sobrescribe vía
-- hypr/shellOverrides.lua en active/inactive/fullscreen_opacity.
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
            active_border   = 0xff458588,   -- El acento (base0D), liso y opaco como en Stylix
            inactive_border = 0xffbdae93,   -- base03, como en Stylix
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

    misc = {
        -- Color que pinta Hyprland donde no hay nada encima: solo se ve mientras Quickshell no
        -- está en marcha (luego lo tapa el fondo de pantalla, quickshell/Background.qml).
        -- Como los colores de los bordes de arriba, solo el valor de ARRANQUE: Theme.qml lo
        -- sobrescribe con base00 del tema elegido vía hypr/shellTheme.lua. Es el de "Gruvbox Claro".
        background_color = 0xfffbf1c7,  -- base00
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

requireIfExists("shellOverrides")   -- gaps_in/gaps_out/border_size (general) y rounding + active/inactive/fullscreen_opacity (decoration), desde el panel GeometrySettings.qml (quickshell/HyprGeometry.qml)
requireIfExists("shellTheme")       -- col.active_border/inactive_border (general) y background_color (misc), según el tema elegido (quickshell/Theme.qml)

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
        kb_layout  = "es",              -- Teclado en español
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

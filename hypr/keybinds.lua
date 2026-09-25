local programs = require("programs")
local monitors = require("monitors")
local terminal = programs.terminal

local mainMod = "SUPER" -- La tecla "Windows" como modificador principal

-- Cada atajo lleva una "description" con el formato "Sección: qué hace". Es lo que
-- muestra la chuleta de atajos de la barra (quickshell/Keybinds.qml), que la lee en
-- vivo con "hyprctl binds -j": un atajo nuevo aparece ahí solo con ponerle descripción.
-- Los que comparten descripción salen juntos en una sola línea (p.ej. las flechas).

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal), { description = "Aplicaciones: Abrir un terminal" })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(),     { description = "Ventanas: Cerrar la ventana" })      -- Cierra la ventana sobre la que esté el ratón (aunque no haya pulsado)

-- Mover el foco con mainMod + flechas
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { description = "Ventanas: Mover el foco" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Ventanas: Mover el foco" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { description = "Ventanas: Mover el foco" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { description = "Ventanas: Mover el foco" })

-- Cambiar de workspace con mainMod + [0-9]
-- Mover la ventana activa a un workspace con mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- El 10 va en la tecla 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}),        { description = "Workspaces: Ir a ese workspace" })
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }), { description = "Workspaces: Mover la ventana a ese workspace" })
end

-- Recorrer los workspaces existentes con mainMod + rueda del ratón
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Siguiente workspace" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Anterior workspace" })
hl.bind("ALT + TAB", hl.dsp.focus({ workspace = "e+1" }),                { description = "Workspaces: Siguiente workspace" })     -- Siguiente Workspace con Alt+Tab

-- Mover/redimensionar ventanas arrastrando con mainMod + clic izquierdo/derecho
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Ventanas: Mover la ventana (arrastrando)" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Ventanas: Cambiar el tamaño de la ventana (arrastrando)" })

-- Teclas multimedia del portátil: volumen y brillo de la pantalla
-- El "qs ipc call osd ..." de detrás muestra el indicador (quickshell/Osd.qml) con el nuevo valor
local osdVolume     = " && qs ipc call osd volume"
local osdBrightness = " && qs ipc call osd brightness"
local osdMic        = " && qs ipc call osd mic"
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" .. osdVolume), { locked = true, repeating = true, description = "Multimedia: Subir el volumen" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" .. osdVolume),      { locked = true, repeating = true, description = "Multimedia: Bajar el volumen" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" .. osdVolume),     { locked = true, description = "Multimedia: Silenciar el sonido" })  -- Sin repeating: al mantenerla pulsada alternaría en bucle
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" .. osdMic),      { locked = true, description = "Multimedia: Silenciar el micrófono" })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+" .. osdBrightness),              { locked = true, repeating = true, description = "Multimedia: Subir el brillo" })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-" .. osdBrightness),              { locked = true, repeating = true, description = "Multimedia: Bajar el brillo" })

-- Necesitan playerctl (está en packages.txt)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Multimedia: Siguiente canción" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Multimedia: Reproducir / pausar" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Multimedia: Reproducir / pausar" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Multimedia: Canción anterior" })

hl.bind("SUPER + I", hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" }), { dont_inhibit = true, description = "Ventanas: Quitar / poner la transparencia" })  -- dont_inhibit intenta (mal) arreglar el comportamiento en fullscreen
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ action = "toggle" }),               { description = "Ventanas: Pantalla completa" })

-- Al pulsar y soltar solo la tecla Super (sin combinar con otra), muestro/oculto el widget inferior
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("qs ipc call launcher toggle"), { release = true, description = "Aplicaciones: Abrir / cerrar el lanzador" })

-- Historial del portapapeles (quickshell/Clipboard.qml)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"), { description = "Aplicaciones: Historial del portapapeles" })

-- No hay un dispatcher (.dsp) para el mirror de los monitores, así que hay que crear una función.
-- En vez de llevar la cuenta en una variable, se mira el estado real cada vez: así acierta
-- aunque el mirror se haya activado desde hyprland.lua o desde otro sitio.
local function isMirroring()
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.is_mirror or #mon.mirrors > 0 then return true end  -- Vale tanto el que copia como el copiado (por si get_monitors() no lista al que copia)
    end
    return false
end

-- Monitor que copian los demás: el panel del portátil si lo hay; si no (sobremesa
-- con varios monitores), el que tiene el foco.
local internalPanel = monitors.internalPanel()      -- Una sola vez: el portátil no cambia de panel

local function mirrorSource()
    if internalPanel then return internalPanel end
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.focused then return mon.name end
    end
    return ""
end

hl.bind("SUPER + M", function()
    if not isMirroring() and #hl.get_monitors() < 2 then return end   -- Con un solo monitor no hay nada que copiar (se copiaría a sí mismo)
    hl.monitor({
        output   = "",                                          -- A todos los monitores
        mirror   = isMirroring() and "" or mirrorSource(),      -- Si ya hay mirror lo quita; si no, todos copian el de mirrorSource()
    })
end, { description = "Monitores: Duplicar las pantallas (activar / desactivar)" })

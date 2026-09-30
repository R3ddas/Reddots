-------------------
---- MONITORES ----
-------------------

-- Para que la config de pantallas no dependa ni del nombre de la máquina ni de a qué
-- conector esté enchufado cada monitor: lo que cambia entre el portátil y el
-- sobremesa se averigua aquí. Lo usan hyprland.lua (reglas de monitor) y keybinds.lua (Super+M).

local M = {}

-- Nombre del panel interno del portátil ("eDP-1", o "LVDS-1" en hardware más antiguo),
-- o nil si no hay (PC de sobremesa). Lo averigua scripts/internal-panel.sh, el mismo
-- que usa la barra (quickshell/shell.qml). No vale hl.get_monitors():
-- al cargar la config todavía está vacío, porque Hyprland crea los monitores después
-- de leer las reglas.
--
-- El script se lanza una sola vez por carga de la config y el resultado se guarda
-- aquí: hyprland.lua y keybinds.lua hacen require() de este mismo módulo, que Lua
-- solo ejecuta una vez, así que los dos comparten "panel". El portátil no cambia de panel.
local panel, panelChecked = nil, false     -- panelChecked: en un sobremesa el resultado es nil y también hay que recordarlo

function M.internalPanel()
    if panelChecked then return panel end
    panelChecked = true
    local out = io.popen("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/internal-panel.sh")
    if not out then return nil end
    panel = out:read("l")           -- nil si no ha escrito nada
    out:close()
    return panel
end

return M

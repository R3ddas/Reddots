-------------------
---- MONITORES ----
-------------------

-- Para que la config de pantallas no dependa ni del nombre de la máquina ni de a qué
-- conector esté enchufado cada monitor: lo que cambia entre el portátil y el
-- sobremesa se averigua aquí. Lo usan hyprland.lua (reglas de monitor) y keybinds.lua (Super+M).

local M = {}

-- Nombre del panel interno del portátil ("eDP-1", o "LVDS-1" en hardware más antiguo),
-- o nil si no hay (PC de sobremesa). Lo averigua scripts/internal-panel.sh, el mismo
-- que usan lid-watcher.sh y la barra (quickshell/shell.qml). No vale hl.get_monitors():
-- al cargar la config todavía está vacío, porque Hyprland crea los monitores después
-- de leer las reglas.
function M.internalPanel()
    local out = io.popen("bash " .. os.getenv("HOME") .. "/.config/hypr/scripts/internal-panel.sh")
    if not out then return nil end
    local name = out:read("l")      -- nil si no ha escrito nada
    out:close()
    return name
end

return M

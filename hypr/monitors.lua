-------------------
---- MONITORES ----
-------------------

-- Para que la config de pantallas no dependa ni del nombre de la máquina ni de a qué
-- conector esté enchufado cada monitor: lo que cambia entre el portátil y el
-- sobremesa se averigua aquí. Lo usan hyprland.lua (reglas de monitor) y keybinds.lua (Super+M).

local M = {}

-- Nombre del panel interno del portátil ("eDP-1", o "LVDS-1" en hardware más antiguo),
-- o nil si no hay (PC de sobremesa). Se saca de los conectores de /sys/class/drm
-- ("card1-eDP-1"...), que ya existen al cargar la config: hl.get_monitors() todavía
-- estaría vacío, porque Hyprland crea los monitores después de leer las reglas.
function M.internalPanel()
    local list = io.popen("ls /sys/class/drm")
    if not list then return nil end
    local connectors = list:read("a")
    list:close()
    return connectors:match("card%d+%-(eDP%-[%w%-]+)") or connectors:match("card%d+%-(LVDS%-[%w%-]+)")
end

return M

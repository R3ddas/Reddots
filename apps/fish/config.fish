source /usr/share/cachyos-fish-config/cachyos-config.fish

if status is-login; and test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    exec start-hyprland                                                             # Arranca hyprland al iniciar la sesión
end

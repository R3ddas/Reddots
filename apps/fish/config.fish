source /usr/share/cachyos-fish-config/cachyos-config.fish

# En la TTY1 se entra solo, sin contraseña (ver "Inicio de sesión" en install.sh): la pide la
# pantalla de bloqueo de Quickshell. Esta marca le dice que bloquee nada más arrancar
# (quickshell/windows/Lock.qml, "markerPath"); la quita ella al desbloquear.
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    touch $XDG_RUNTIME_DIR/reddots-locked
    exec start-hyprland                                                             # Arranca hyprland al iniciar la sesión
end

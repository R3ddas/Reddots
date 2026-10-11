source /usr/share/cachyos-fish-config/cachyos-config.fish

# Idioma de los textos del sistema, el que se elige con el de la interfaz en el menú de
# Reddots (quickshell/services/Lang.qml, que escribe este archivo). Solo los mensajes: las
# fechas, números, moneda... siguen los de LANG. En cada shell y no solo al entrar, para que
# un terminal nuevo salga ya en el idioma nuevo aunque Hyprland arrancara con el anterior
set -l stateDir $HOME/.local/state
set -q XDG_STATE_HOME; and set stateDir $XDG_STATE_HOME
if test -r $stateDir/reddots/lc_messages
    set -gx LC_MESSAGES (string trim < $stateDir/reddots/lc_messages)
end

# En la TTY1 se entra solo, sin contraseña (ver "Inicio de sesión" en install.sh): la pide la
# pantalla de bloqueo de Quickshell. Esta marca le dice que bloquee nada más arrancar
# (quickshell/windows/Lock.qml, "markerPath"); la quita ella al desbloquear.
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    touch $XDG_RUNTIME_DIR/reddots-locked
    # Las apps que arrancan systemd o D-Bus (portales...) no salen de esta shell: se les pasa aparte
    set -q LC_MESSAGES; and systemctl --user set-environment LC_MESSAGES=$LC_MESSAGES
    exec start-hyprland                                                             # Arranca hyprland al iniciar la sesión
end

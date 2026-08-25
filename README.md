# Reddots

Para que hyprland arranque automáticamente, añadir al final de config.fish:

if status is-login; and test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
    exec start-hyprland
end

Si prefieres no mezclarlo con tu configuración (útil para tus dotfiles de Reddots), fish también lee todo lo que haya en ~/.config/fish/conf.d/*.fish. Puedes crear ahí ~/.config/fish/conf.d/zz-hyprland-autostart.fish con ese mismo bloque: queda aislado en su propio fichero y se borra o desactiva sin tocar nada más. El zz- es para que ordene al final alfabéticamente, ya que conf.d se carga antes que config.fish.

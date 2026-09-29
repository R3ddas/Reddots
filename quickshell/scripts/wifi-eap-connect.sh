#!/usr/bin/env bash
# Crea y activa un perfil wifi 802.1X (PEAP + MSCHAPv2, lo habitual en eduroam) para Network.qml.
# Uso: wifi-eap-connect.sh <ssid> <usuario> [--sin-verificar]    (la contraseña llega por la entrada estándar, una línea)
# Sale con 0 si conecta, 2 si no se pudo verificar el servidor RADIUS y 1 con cualquier otro fallo.
# Si no conecta borra el perfil, para poder reintentarlo con otros datos.
#
# La contraseña nunca va en la línea de comandos (ni de este script ni de nmcli): los argumentos
# de cualquier proceso se ven con "ps" mientras dura. Llega por la entrada estándar y se le pasa a
# nmcli con passwd-file, a través de un <(printf ...): printf es interno de bash, no un proceso aparte.
# NetworkManager la guarda en el perfil al conectar (como cuando la pide un applet), así que las
# siguientes veces conecta solo.

ssid=$1 identity=$2
IFS= read -r password
exec </dev/null                 # Ya leída: que nmcli no se quede esperando nada por aquí

args=(type wifi con-name "$ssid" ssid "$ssid" wifi-sec.key-mgmt wpa-eap
      802-1x.eap peap 802-1x.phase2-auth mschapv2
      802-1x.identity "$identity")

# Verificación del servidor: certificado firmado por una CA del sistema y a nombre del dominio
# del usuario (jailopez@ing.uc3m.es -> uc3m.es), para no entregar la contraseña a una red falsa
if [[ $3 != --sin-verificar ]]; then
    args+=(802-1x.system-ca-certs yes)
    if [[ $identity == *@* ]]; then
        domain=$(psl --print-reg-domain "${identity#*@}" | sed 's/.*: //')
        [[ -n $domain ]] && args+=(802-1x.domain-suffix-match "$domain")
    fi
fi

since=$(date +%s)
nmcli connection add "${args[@]}" >/dev/null || exit 1
nmcli connection up id "$ssid" passwd-file <(printf '802-1x.password:%s\n' "$password") >/dev/null && exit 0

nmcli connection delete id "$ssid" >/dev/null
journalctl -u wpa_supplicant --since "@$since" --no-pager -q | grep -q 'TLS-CERT-ERROR' && exit 2
exit 1

#!/bin/bash

TZ=${TZ:-UTC}

SAMBA_WORKGROUP=${SAMBA_WORKGROUP:-WORKGROUP}
SAMBA_SERVER_STRING=${SAMBA_SERVER_STRING:-Docker Samba Server}
SAMBA_LOG_LEVEL=${SAMBA_LOG_LEVEL:-0}
SAMBA_FOLLOW_SYMLINKS=${SAMBA_FOLLOW_SYMLINKS:-yes}
SAMBA_WIDE_LINKS=${SAMBA_WIDE_LINKS:-yes}
SAMBA_SERVER_MIN_PROTOCOL=${SAMBA_SERVER_MIN_PROTOCOL:-SMB2}
SAMBA_SERVER_MAX_PROTOCOL=${SAMBA_SERVER_MAX_PROTOCOL:-SMB3}

echo "Setting timezone to ${TZ}"
ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime
echo ${TZ} > /etc/timezone

echo "Initializing files and folders"
mkdir -p /data/cache /data/lib
if [ -z "$(ls -A /data/lib)" ]; then
  cp -r /var/lib/samba/* /data/lib/
fi
rm -rf /var/lib/cache /var/lib/samba
ln -sf /data/cache /var/cache/samba
ln -sf /data/lib /var/lib/samba

echo "Setting global configuration"
  cat > /etc/samba/smb.conf <<EOL
[global]
workgroup = ${SAMBA_WORKGROUP}
server string = ${SAMBA_SERVER_STRING}
server role = standalone server

log level = ${SAMBA_LOG_LEVEL}
;log file = /usr/local/samba/var/log.%m
;max log size = 50

hosts allow = 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
security = user
guest account = nobody
pam password change = yes
map to guest = bad user
usershare allow guests = yes

create mask = 0664
force create mode = 0664
directory mask = 0775
force directory mode = 0775
follow symlinks = ${SAMBA_FOLLOW_SYMLINKS}
wide links = ${SAMBA_WIDE_LINKS}
unix extensions = no

printing = bsd
printcap name = /dev/null
disable spoolss = yes

client ipc min protocol = default
client min protocol = CORE
server min protocol = ${SAMBA_SERVER_MIN_PROTOCOL}
client ipc max protocol = default
client max protocol = default
server max protocol = ${SAMBA_SERVER_MAX_PROTOCOL}

;wins support = yes
;wins server = w.x.y.z
;wins proxy = yes
dns proxy = no
socket options = TCP_NODELAY
strict locking = no
local master = no

vfs objects = fruit streams_xattr
fruit:metadata = stream
fruit:model = MacSamba
fruit:posix_rename = yes
fruit:veto_appledouble = no
fruit:wipe_intentionally_left_blank_rfork = yes
fruit:delete_empty_adfiles = yes

;realm = MY_REALM
;passdb backend = tdbsam
;include = /usr/local/samba/lib/smb.conf.%m
;interfaces = 192.168.12.2/24 192.168.13.2/24
;logon path = \\%L\Profiles\%U

;add user script = /usr/sbin/useradd %u
;add group script = /usr/sbin/groupadd %g
;add machine script = /usr/sbin/adduser -n -g machines -c Machine -d /dev/null -s /bin/false %u
;delete user script = /usr/sbin/userdel %u
;delete user from group script = /usr/sbin/deluser %u %g
;delete group script = /usr/sbin/groupdel %g

EOL

for auth in $(yq -j read /data/config.yml | jq -r '.auth[] | @base64'); do
  _jq() {
    echo "${auth}" | base64 --decode | jq -r "${1}"
  }
  echo "Creating user $(_jq '.user')/$(_jq '.group') ($(_jq '.uid'):$(_jq '.gid'))"
  id -g "$(_jq '.gid')" &>/dev/null || id -gn "$(_jq '.group')" &>/dev/null || addgroup -g "$(_jq '.gid')" -S "$(_jq '.group')"
  id -u "$(_jq '.uid')" &>/dev/null || id -un "$(_jq '.user')" &>/dev/null || adduser -u "$(_jq '.uid')" -G "$(_jq '.group')" "$(_jq '.user')" -SHD
  echo -e "$(_jq '.password')\n$(_jq '.password')" | smbpasswd -a -s "$(_jq '.user')"
done

for share in $(yq -j read /data/config.yml | jq -r '.share[] | @base64'); do
  _jq() {
    echo "${share}" | base64 --decode | jq -r "${1}"
  }
  echo "Creating share $(_jq '.name')"
  if [[ "$(_jq '.name')" = "null" ]] || [[ -z "$(_jq '.name')" ]]; then
    >&2 echo "ERROR: Name required"
    exit 1
  fi
  echo -e "\n[$(_jq '.name')]" >> /etc/samba/smb.conf
  if [[ "$(_jq '.path')" = "null" ]] || [[ -z "$(_jq '.path')" ]]; then
    >&2 echo "ERROR: Path required"
    exit 1
  fi
  echo "path = $(_jq '.path')" >> /etc/samba/smb.conf
  if [[ "$(_jq '.comment')" != "null" ]] && [[ -n "$(_jq '.comment')" ]]; then
    echo "comment = $(_jq '.comment')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.browsable')" = "null" ]] || [[ -z "$(_jq '.browsable')" ]]; then
    echo "browsable = yes" >> /etc/samba/smb.conf
  else
    echo "browsable = $(_jq '.browsable')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.readonly')" = "null" ]] || [[ -z "$(_jq '.readonly')" ]]; then
    echo "read only = yes" >> /etc/samba/smb.conf
  else
    echo "read only = $(_jq '.readonly')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.guestok')" = "null" ]] || [[ -z "$(_jq '.guestok')" ]]; then
    echo "guest ok = yes" >> /etc/samba/smb.conf
  else
    echo "guest ok = $(_jq '.guestok')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.validusers')" != "null" ]] && [[ -n "$(_jq '.validusers')" ]]; then
    echo "valid users = $(_jq '.validusers')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.adminusers')" != "null" ]] && [[ -n "$(_jq '.adminusers')" ]]; then
    echo "admin users = $(_jq '.adminusers')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.writelist')" != "null" ]] && [[ -n "$(_jq '.writelist')" ]]; then
    echo "write list = $(_jq '.writelist')" >> /etc/samba/smb.conf
  fi
  if [[ "$(_jq '.veto')" != "null" ]] && [[ "$(_jq '.veto')" = "no" ]]; then
    echo "veto files = /._*/.apdisk/.AppleDouble/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/" >> /etc/samba/smb.conf
    echo "delete veto files = yes" >> /etc/samba/smb.conf
  fi
done

testparm -s

exec "$@"
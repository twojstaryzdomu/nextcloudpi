#!/usr/bin/env bash

set -e

echo "Update root shell..."
if getent passwd "root" | grep -e '/usr/sbin/nologin'
then
  sed -i '/^root/s|/usr/sbin/nologin|/bin/bash|' /etc/passwd
fi
echo "done."

echo "Fixing trusted proxies list..."
for i in {10..15}
do
  proxy="$(ncc config:system:get trusted_proxies "$i" || echo 'NONE')"
  [[ "$proxy" == 'NONE' ]] || python3 -c "import ipaddress; ipaddress.ip_address('${proxy}')" > /dev/null 2>&1 || ncc config:system:delete trusted_proxies "$i"
done
echo "done."

echo "Updating PHP package signing key..."
[ -n "${NOUPDATE}" ] || apt-get update
apt-get install --no-install-recommends -y gnupg2

apt-key adv --fetch-keys https://packages.sury.org/php/apt.gpg
echo "done."

echo "Installing dependencies..."
apt-get install --no-install-recommends -y tmux
echo "done."

echo "Updating obsolete theming URL"
if [[ "$(ncc config:app:get theming url)" == "https://ownyourbits.com" ]]
then
   ncc config:app:set theming url --value="https://nextcloudpi.com"
fi
echo "done."

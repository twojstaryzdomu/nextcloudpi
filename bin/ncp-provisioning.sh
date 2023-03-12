#!/bin/bash

# this script runs at startup to provide an unique random passwords for each instance

source /usr/local/etc/library.sh
set -x
## redis provisioning

CFG=/var/www/nextcloud/config/config.php
REDISPASS="$( grep -Po "(?<=^requirepass)\s+\K\S+" ${REDIS_CONF} )"

### IF redis password is the default one or missing, generate a new one

[[ "$REDISPASS" == "default" || "$REDISPASS" == "" ]] && {
  REDISPASS="$( openssl rand -base64 32 )"
  echo Provisioning Redis password
  grep -q "^requirepass" ${REDIS_CONF} \
    && sed -i -E "s|^requirepass .*|requirepass $REDISPASS|" ${REDIS_CONF} \
    || echo "requirepass $REDISPASS" >> ${REDIS_CONF}
  chown redis:redis ${REDIS_CONF}
  is_docker || systemctl restart redis
}

### If there exists already a configuration adjust the password
[[ -f "$CFG" ]] && {
  echo "Updating NextCloud config with Redis password"
  sed -i "s|'password'.*|'password' => '$REDISPASS',|" "$CFG"
}

## mariaDB provisioning

DBADMIN=ncadmin
DBPASSWD=$( grep password /root/.my.cnf | sed 's|password=||' )

[[ "$DBPASSWD" == "default" ]] && {
  DBPASSWD=$( openssl rand -base64 32 )
  echo Provisioning MariaDB password
  echo -e "[client]\npassword=$DBPASSWD" > /root/.my.cnf
  chmod 600 /root/.my.cnf
  mysql <<EOF
GRANT USAGE ON *.* TO '$DBADMIN'@'localhost' IDENTIFIED BY '$DBPASSWD';
DROP USER '$DBADMIN'@'localhost';
CREATE USER '$DBADMIN'@'localhost' IDENTIFIED BY '$DBPASSWD';
GRANT ALL PRIVILEGES ON nextcloud.* TO $DBADMIN@localhost;
FLUSH PRIVILEGES;
EXIT
EOF
}

[[ -f "$CFG" ]] && {
  echo "Updating NextCloud config with MariaDB password"
  sed -i "s|'dbpassword' =>.*|'dbpassword' => '$DBPASSWD',|" "$CFG"
}

## nc.limits.sh (auto)adjustments: number of threads, memory limits...

source /usr/local/etc/library.sh
run_app nc-limits

## Check for interrupted upgrades and rollback
BKP="$( ls -1t /var/www/nextcloud-bkp_*.tar.gz 2>/dev/null | head -1 )"
[[ -f "$BKP" ]] && [[ "$( stat -c %U "$BKP" )" == "root" ]] && [[ "$( stat -c %a "$BKP" )" == 600 ]] && {
  echo "Detected interrupted upgrade. Restoring..."
  BKP_NEW="failed_$BKP"
  mv "$BKP" "$BKP_NEW"
  ncp-restore "$BKP_NEW" && rm "$BKP_NEW"
}

## Check for encrypted data and ask for password
if needs_decrypt; then
  echo "Detected encrypted instance"
  a2dissite ncp 001-nextcloud
  a2ensite ncp-activation
  apache2ctl -k graceful
fi

[[ -f /usr/local/etc/instance.cfg ]] || {
  cohorte_id=$((RANDOM % 100))
  cat > /usr/local/etc/instance.cfg <<EOF
{
  "cohorteId": ${cohorte_id}
}
EOF
  cat /usr/local/etc/instance.cfg
}


exit 0

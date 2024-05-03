#!/bin/bash

[ -n "${NOUPDATE}" ] || apt-get update
apt-get install -y --no-install-recommends logrotate

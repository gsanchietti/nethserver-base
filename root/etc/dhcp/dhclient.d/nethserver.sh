#!/bin/bash
#
# Copyright (C) 2014 Nethesis S.r.l.
# http://www.nethesis.it - support@nethesis.it
#
# This script is part of NethServer.
#
# NethServer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License,
# or any later version.
#
# NethServer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NethServer.
#

CACHE_DIR=/var/cache/nethserver
CACHE_FILE=$CACHE_DIR/${interface}_ipaddr

write_cache() {
    echo -n "${new_ip_address} ${new_subnet_mask}" > $CACHE_FILE
}

nethserver_config() {
    role=`/sbin/e-smith/db networks getprop ${interface} role`
    if [ "$role" == "red" ]; then
        if [ ! -d $CACHE_DIR ]; then
            mkdir $CACHE_DIR
        fi
        if [ ! -f $CACHE_FILE ]; then
            write_cache
        else
            ipaddr=`cut -f1 -d' ' $CACHE_FILE`
            netmask=`cut -f2 -d' ' $CACHE_FILE`
            if [ "$ipaddr" != ${new_ip_address} ] || [ "$netmask" != "${new_subnet_mask}" ]; then
                write_cache
                /sbin/e-smith/signal-event static-routes-save
                /sbin/e-smith/signal-event firewall-adjust
            fi
        fi
    elif [ "$role" == "green" ]; then
        ipaddr=`/sbin/e-smith/db networks getprop ${interface} ipaddr`
        netmask=`/sbin/e-smith/db networks getprop ${interface} netmask`
        if [ "$ipaddr" != ${new_ip_address} ] || [ "$netmask" != "${new_subnet_mask}" ]; then
            /sbin/e-smith/db networks setprop ${interface} ipaddr ${new_ip_address}
            /sbin/e-smith/db networks setprop ${interface} netmask ${new_subnet_mask}
        fi
    fi
}

nethserver_restore() {
  true
}


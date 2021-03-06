#!/bin/bash
#
# Add blocklist.de's list for very abusive IP-s to iptables.
#
# VERSION       :0.3
# DATE          :2015-06-08
# AUTHOR        :Viktor Szépe <viktor@szepe.net>
# LICENSE       :The MIT License (MIT)
# URL           :https://github.com/szepeviktor/debian-server-tools
# BASH-VERSION  :4.2+
# LOCATION      :/usr/local/sbin/blocklist-de-add.sh
# CRON.D        :10 7	* * *	root	/usr/local/sbin/blocklist-de-add.sh

A5K_URL="http://lists.blocklist.de/lists/strongips.txt"
A5K_CHAIN="ATTACKER5K"
IPTABLES="/sbin/iptables"

isIP() {
    local TOBEIP="$1"
    local OCTET="([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"

    [[ "$TOBEIP" =~ ^${OCTET}\.${OCTET}\.${OCTET}\.${OCTET}$ ]]
}

# Check iptables executable
if ! [ -x "$IPTABLES" ]; then
    echo "iptables executable not found (${IPTABLES})" >&2
    exit 1
fi

# Check list integrity
A5K_MD5="$(wget -qO- "${A5K_URL}.md5")"
A5K_TMP="$(tempfile)"
trap "rm '$A5K_TMP' &> /dev/null" EXIT

wget -qO "$A5K_TMP" "$A5K_URL"
if ! [ -s "$A5K_TMP" ]; then
    echo "blocklist.de's strongips list download failed." >&2
    exit 2
fi

A5K_LIST_MD5="$(md5sum "$A5K_TMP")"
A5K_LIST_MD5="${A5K_LIST_MD5%% *}"
if [ "$A5K_LIST_MD5" != "$A5K_MD5" ]; then
    echo "blocklist.de's strongips list integrity failed." >&2
    echo "Downloaded MD5 (${A5K_MD5}), calculated MD5 (${A5K_LIST_MD5}), list length in bytes ($(wc -c < "$A5K_TMP"))." >&2
    exit 3
fi

# Remove from INPUT chain for now
"$IPTABLES" -D INPUT -j "$A5K_CHAIN" &> /dev/null

# Set up chain and rules
"$IPTABLES" -N "$A5K_CHAIN" &> /dev/null
"$IPTABLES" -F "$A5K_CHAIN"
while read A5K; do
    isIP "$A5K" && "$IPTABLES" -A "$A5K_CHAIN" -s "$A5K" -j DROP
done < "$A5K_TMP"
"$IPTABLES" -A "$A5K_CHAIN" -j RETURN

# Add back to INPUT
"$IPTABLES" -C INPUT -j "$A5K_CHAIN" &> /dev/null || "$IPTABLES" -I INPUT -j "$A5K_CHAIN"

tty --quiet && "$IPTABLES" -n -L "$A5K_CHAIN" | grep -w "^DROP" | wc -l

exit 0

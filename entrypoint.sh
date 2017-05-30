#!/bin/sh

LOG_DIR="/data/bind/log";
if [ ! -d "$LOG_DIR" ]; then mkdir -p $LOG_DIR && chown bind $LOG_DIR; fi

if [ -z $DNS_FORWARDER ]; then DNS_FORWARDER="none"; fi
if [ -z $DNS_BLACKHOLE ]; then DNS_BLACKHOLE="null"; fi

# DNSCrypt config
if [ "$DNS_FORWARDER" = "dnscrypt" ]; then
  # DNSCrypt resolver list and config
  echo "[*] Updating DNSCrypt Resolver List"
  wget \
    -O /data/dnscrypt/dnscrypt-resolvers.csv \
    https://raw.githubusercontent.com/jedisct1/dnscrypt-proxy/master/dnscrypt-resolvers.csv
  chown dnscrypt /data/dnscrypt/dnscrypt-resolvers.csv
  chown dnscrypt /data/dnscrypt/dnscrypt-proxy.conf

  # Run DNSCrypt
  echo "[*] Starting DNSCrypt Proxy"
  /usr/sbin/dnscrypt-proxy /data/dnscrypt/dnscrypt-proxy.conf;
fi;



MASTER_FILE="/data/bind/etc/master_blacklist"
BLACKLIST_PATH="/data/bind/etc/blacklist.d"

# Update yoyo DNS blacklist
echo "[*] Updating yoyo DNS blacklist"
YOYO_FILE="$BLACKLIST_PATH/yoyo"
wget -O $YOYO_FILE "https://pgl.yoyo.org/as/serverlist.php?hostformat=nohtml&showintro=0"

# Merge blacklists
echo "[*] Merging DNS blacklists"
for BLACKLIST_FILE in $(ls $BLACKLIST_PATH); do
  cat "$BLACKLIST_PATH/$BLACKLIST_FILE" >> "$MASTER_FILE.tmp"
done;
sort -u "$MASTER_FILE.tmp" | sed -r \
  "s/(.*)/zone \"\1\" { type master; notify no; file \"\/data\/bind\/etc\/zones\/blackhole\"; };/g" \
   > "$MASTER_FILE"
rm "$MASTER_FILE.tmp"

# Blacklist permissions
chown -R bind $BLACKLIST_PATH
chmod 775 $BLACKLIST_PATH
chmod 664 $BLACKLIST_PATH/*



# Link forwarder
echo "[*] Forwarding DNS to: [$DNS_FORWARDER]"
ln -sf \
  "/data/bind/etc/forwarders/$DNS_FORWARDER" \
  "/data/bind/etc/enabled_forwarder"

# Configure blackhole zone
echo "[*] Blackhole to: [$DNS_BLACKHOLE]"
cat "/data/bind/etc/zones/blackhole_template" | sed -r "s/XXXXXXXX/$DNS_BLACKHOLE/g" > "/data/bind/etc/zones/blackhole"

# Permissions
chown -R bind /data/bind/etc
chmod 775 /data/bind/etc

chown -R bind /data/bind/etc/forwarders
chmod 775 /data/bind/etc/forwarders
chmod 664 /data/bind/etc/forwarders/*

chown -R bind /data/bind/etc/zones
chmod 775 /data/bind/etc/zones
chmod 664 /data/bind/etc/zones/*

chmod 775 /data/bind/log

# Start BIND
echo "[*] Starting BIND Nameserver"
/usr/sbin/named -u bind -c /data/bind/etc/named.conf -4
tail -f /data/bind/log/default.log

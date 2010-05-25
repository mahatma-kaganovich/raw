# /etc/conf.d/drbd: config file for /etc/init.d/drbd

# place dependences here
#DRBD_CLIENTS="heartbeat ocfs2"

# "yes" to force primary if configured even if no UpToDate node connected
# I use with dual-primary & "wfc-timeout 0;" for HA/emergency degraded primary
DRBD_FORCE_PRIMARY="no"

# "yes" to wait_connect inside script, no wait-con-int
DRBD_HIDE_WAIT="no"

# this values default and good for most cases (empty to status-waiting):
# wait for all after connect, usually just a smart delay  (do "0" to full sync)
#DRBD_WAIT_SYNC="wait-sync --wait-after-sb --outdated-wfc-timeout=5 --degr-wfc-timeout=5 --wfc-timeout=5"
# wait before primary exclude SyncSource, unlimited unless documented data loss
#DRBD_WAIT_PRIMARY="wait-sync --wait-after-sb --outdated-wfc-timeout=0 --degr-wfc-timeout=0 --wfc-timeout=0"
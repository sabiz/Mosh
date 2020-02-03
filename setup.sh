#! /bin/bash

# -----------------------------------------
# Generate configuration file for [mo.sh]
# -----------------------------------------

CONFIG_FILE_NAME='config.sh'
DISK_LIST=$(lsblk -l -p -o NAME,TYPE,MOUNTPOINT |grep  -P '.+(disk|part) /(?!boot)' | cut -d" " -f1|xargs)
ETH_INTERFACES=$(ls -l  /sys/class/net |grep -v '/virtual/' | cut -d " " -f 11 | xargs)

echo '# CONFIGURATIONS' > $CONFIG_FILE_NAME
echo "DISK_LIST=($DISK_LIST)" >> $CONFIG_FILE_NAME
echo "ETH_INTERFACES=($ETH_INTERFACES)" >> $CONFIG_FILE_NAME
echo "MIDDLE_BAR_SIZE=24" >> $CONFIG_FILE_NAME
echo "HALF_BAR_SIZE=16" >> $CONFIG_FILE_NAME
echo "MIN_BAR_SIZE=8" >> $CONFIG_FILE_NAME
echo 'TEMP_FILE_PATH=$(mktemp -d)' >> $CONFIG_FILE_NAME
echo "SLEEP_TIME=1" >> $CONFIG_FILE_NAME



#/bin/bash -eu

##########################
# Mosh
##########################

# -----------------------
# load onfigurations
source ./config.sh
# -----------------------

render() {
    tput cup 0 0
    local termLine=$(tput lines)
    local printLine=0
    for f in $@ ; do
        cat $f | while read line
        do
            echo -en "\e[K"
            echo -e "$line"
            printLine=$((printLine + 1))
        done
    done
    local clearLine=$((termLine - printLine))
    if [ $clearLine -gt 0 ]; then
        for i in `seq 1 $clearLine`; do
            echo -en "\e[E\e[K"
        done
    fi
}

echoBuffer() {
    eval echo -en \"\$$BUFFER_NAME\"
}

prettyPrint(){
    while read line
    do
        eval $BUFFER_NAME=\"\$\{$BUFFER_NAME\}\"\"$(printf '%s' '$line\\n')\"
    done <<-END
	$1
	END
# hard tab でないと動かない
}


prettyPrintNoReturn(){
    while read line
    do
        eval $BUFFER_NAME=\"\$\{$BUFFER_NAME\}\"\"$(printf '%s' '$line')\"
    done <<-END
	$1
	END
# hard tab でないと動かない
}

printBar(){
    local cols=$(($(tput cols) - 10))
    printFixSizeBar $1 $cols
    printClear
}

printFixSizeBar(){
    local cols=$2
    local progress=$(echo "($cols * ($1 * 0.01))" | bc | sed -e 's/^\./0./g')
    progress=${progress%.*}
    local pipe=$(echo $progress| awk '{for(i=0;i<$1;i++)x=x"▮";print x}')
    local space=`expr $cols - ${progress}`
    local space=$(echo $space| awk '{for(i=0;i<$1;i++)x=x"▯";print x}')

    local progressStr=`printf "%3d%%" $1`
    if test $1 -le 15; then
        local barColor=69
    elif test $1 -le 45; then
        local barColor=112
    elif test $1 -le 70; then
        local barColor=214
    else
        local barColor=197
    fi

    local line=$(echo -e "\\e[38;5;${barColor}m$progressStr \\e[0m\\e[38;5;${barColor}m$pipe\\e[0m$space")
    prettyPrintNoReturn "$line"
}

printTitle(){
    local cols=$(($(tput cols) / 2 - ${#1} / 2 - 4))
    local line=`printf -- -"%.s" $(eval echo {0..$cols})`
    line=$(echo  -e "\\e[38;5;226m$line[ $1 ]$line\\e[0m")
    prettyPrint "$line"
}

printSubTitle() {
    local line=$(echo -e "\\e[38;5;227m$1\\e[0m")
    prettyPrint "$line"
}

printSubTitleNoReturn() {
    local line=$(echo -e "\\e[38;5;227m$1\\e[0m")
    prettyPrintNoReturn "$line"
}

printDetailTitle() {
    local line=$(echo -e "\\e[38;5;230m$1\\e[0m")
    prettyPrintNoReturn "$line"
}

printClear() {
    prettyPrint "  "
}

printSeparator(){
    printClear
    local cols=$(($(tput cols) - 4))
    local line=`printf -- -"%.s" $(eval echo {1..$cols})`
    line=$(echo  -e \\e[96m\<\<$line\>\>\\e[0m)
    prettyPrint $line
    printClear
}

convertByte2() {
    local k=1024
    local m="$k*$k"
    local g="$m*$k"
    local t="$g*$k"
    local p="$t*$k"
    local ret=$1
    local unit="byte"
    for u in KB MB GB TB PB; do
        case $u in
        KB) local n=$k;;
        MB) local n=$m;;
        GB) local n=$g;;
        TB) local n=$t;;
        PB) local n=$p;;
        esac
        local tmp=$(echo "$1/($n)" | bc | sed "s/^\./0\./")
        if [ $tmp = 0 ]; then
            break
        fi
        ret=$tmp
        unit=$u
    done
    echo -n "$ret $unit"
}

#############################################################################################################

# GPU STATUS

#############################################################################################################

printGpuStatus() {
    type nvidia-smi >/dev/null 2>&1||return 0
    printTitle "GPU"
    gpuCount=$(nvidia-smi -L | wc -l)
    for id in `seq 0 $(($gpuCount - 1))`; do
        local queryResult=$(nvidia-smi --id=$id --format=csv,noheader --query-gpu=driver_version,name,temperature.gpu,fan.speed,utilization.gpu,memory.total,memory.used,power.max_limit,power.draw)
        queryResult="${queryResult//, /,}"

        local fanSpeed=$(echo $queryResult | cut -d, -f4 | cut -d' ' -f1)
        local utilization=$(echo $queryResult | cut -d, -f5 | cut -d' ' -f1)

        local memoryTotal=$(echo $queryResult | cut -d, -f6)
        local memoryUsed=$(echo $queryResult | cut -d, -f7)
        local memoryTotalNum=`echo -n $memoryTotal | cut -d' ' -f1`
        local memoryUsedNum=`echo -n $memoryUsed | cut -d' ' -f1`
        local memoryUsage=$(echo "scale=5; ($memoryUsedNum / $memoryTotalNum * 100)" | bc | sed -e 's/^\./0./g')
        memoryUsage=${memoryUsage%.*}

        local powerTotal=$(echo $queryResult | cut -d, -f8)
        local powerUsed=$(echo $queryResult | cut -d, -f9)
        local powerTotalNum=`echo -n $powerTotal | cut -d' ' -f1`
        local powerUsedNum=`echo -n $powerUsed | cut -d' ' -f1`
        local power=$(echo "scale=5; ($powerUsedNum / $powerTotalNum * 100)" | bc | sed -e 's/^\./0./g')
        power=${power%.*}

        printSubTitleNoReturn "GPU:"
        prettyPrintNoReturn "$id:$(echo $queryResult | cut -d, -f2)"
        printClear

        printDetailTitle "[ Driver Version ] "
        prettyPrintNoReturn "$(echo $queryResult | cut -d, -f1)"
        printClear
        printDetailTitle "[ Temp ] "
        prettyPrintNoReturn "$(echo $queryResult | cut -d, -f3)℃"
        printClear

        printDetailTitle "[ Fan Speed    ] "
        printFixSizeBar $fanSpeed $HALF_BAR_SIZE
        printDetailTitle "   [ Utilization ]"
        printFixSizeBar $utilization $HALF_BAR_SIZE
        printClear

        printDetailTitle "[ Memory Usage ] "
        printFixSizeBar $memoryUsage $HALF_BAR_SIZE
        printDetailTitle "     \\e[38;5;208m$memoryUsed / $memoryTotal\\e[0m"
        printClear

        printDetailTitle "[ Power        ] "
        printFixSizeBar $power $HALF_BAR_SIZE
        printDetailTitle "     \\e[38;5;208m$powerUsed / $powerTotal\\e[0m"
        printClear
        printClear
    done

    printSubTitle "[ Process ]"
    local gpuProcess=$(nvidia-smi)
    local processLine=$(((`echo -e "$gpuProcess" |grep -En "^\s+$" | cut -d: -f1`) + 1))
    prettyPrint "$(echo -e "$gpuProcess" | tail -n +$processLine)"
}

#############################################################################################################

# SYSTEM STATUS

#############################################################################################################

printSystemHost() {
    printSubTitleNoReturn "[ Host ] "
    printDetailTitle "\\e[38;5;141m$(whoami)\\e[0m@\\e[38;5;141m$(hostname)\\e[0m"
    if [ -n "$ETH_INTERFACES" ]; then
        local ipv4=$(ip address show $ETH_INTERFACES | grep "inet " | tr -s " " | cut -d" " -f 3 | cut -d/ -f 1)
        printDetailTitle " (\\e[38;5;147m$ipv4\\e[0m)"
    fi
    printClear
}

printSystemLoadAverage() {
    printSubTitle "[ Load average ]"
    local loadAverages=($(uptime | tr -s ' ' | sed 's/.*average://g' | tr -s , ' '))
    printDetailTitle " [ 1m ] "
    prettyPrintNoReturn "${loadAverages[0]}"
    printDetailTitle "   [ 5m ] "
    prettyPrintNoReturn "${loadAverages[1]}"
    printDetailTitle "   [ 15m ] "
    prettyPrintNoReturn "${loadAverages[2]}"
    printClear
}

printSystemCpu() {
    printSubTitle "[ CPU ]"
    local cpuNum=$(grep processor /proc/cpuinfo | wc -l)
    local cpuUsages=$(mpstat -P ALL -u 1 1 | tail -n $cpuNum | tr -s ' ' ,)
    for id in `seq 0 $(($cpuNum - 1))`; do
        local core=$(echo "scale=5; 100 - $(echo -en "$cpuUsages" | tail -n $(($id + 1)) | head -n 1 | cut -d, -f12)" | bc | sed -e 's/^\./0./g')
        core=${core%.*}
        if [ `expr $id % 2` == 1 ]; then
            printDetailTitle "    [ Core$(printf %02d $id)  ] "
        else
            printDetailTitle "[ Core$(printf %02d $id)  ] "

        fi
        printFixSizeBar $core $HALF_BAR_SIZE
        if [ `expr $id % 2` == 1 ]; then
            printClear
        fi
    done
    printClear
}

printSystemMemory() {
    printSubTitle "[ Memory ]"
    local memoryStatus=($(free | tail -n +2 | tr -s ' ' | tr -s '\n' ' '))
    local memoryStatusReadable=($(free -h | tail -n +2 | tr -s ' ' | tr -s '\n' ' '))

    local memoryTotal=${memoryStatus[1]}
    local memoryTotalReadable=${memoryStatusReadable[1]}
    local memoryUsed=${memoryStatus[2]}
    local memoryUsedReadable=${memoryStatusReadable[2]}

    local swapTotal=${memoryStatus[8]}
    local swapTotalReadable=${memoryStatusReadable[8]}
    local swapUsed=${memoryStatus[9]}
    local swapUsedReadable=${memoryStatusReadable[9]}

    local memoryUsage=$(echo "scale=5; ($memoryUsed / $memoryTotal * 100)" | bc | sed -e 's/^\./0./g')
    local memoryUsage=${memoryUsage%.*}
    local swapUsage=$(echo "scale=5; ($swapUsed / $swapTotal * 100)" | bc | sed -e 's/^\./0./g')
    local swapUsage=${swapUsage%.*}
    printDetailTitle "[ Usage  ] "
    printFixSizeBar $memoryUsage $HALF_BAR_SIZE
    printDetailTitle "     \\e[38;5;208m$memoryUsedReadable / $memoryTotalReadable\\e[0m"
    printClear
    printDetailTitle "[ Swap   ] "
    printFixSizeBar $swapUsage $HALF_BAR_SIZE
    printDetailTitle "     \\e[38;5;208m$swapUsedReadable / $swapTotalReadable\\e[0m"
    printClear
}

printSystemDisk() {
    if [ -n "$DISK_LIST" ]; then
        printSubTitle "[ Disk ]"
        local statA=$(iostat -d)
        sleep 1s
        local statB=$(iostat -d)
        for i in `seq 0 $((${#DISK_LIST[@]} - 1))`; do
            local disk=($(df -hl --output=size,used,pcent ${DISK_LIST[$i]} | tail -n +2))
            local diskTotal=${disk[0]}
            local diskUsed=${disk[1]}
            local diskUsage=$(echo "${disk[2]}" | sed 's/%//g')
            local diskName=$(basename ${DISK_LIST[$i]} | sed -e "s/[0-9]//g")
            local diskStatA=($(echo "$statA" | grep -E "^$diskName" | xargs))
            local diskStatB=($(echo "$statB" | grep -E "^$diskName" | xargs))
            local readA=$(echo "${diskStatA[4]} * 1024" | bc | sed -e 's/^\./0./g')
            local writeA=$(echo "${diskStatA[5]} * 1024" | bc | sed -e 's/^\./0./g')
            local readB=$(echo "${diskStatB[4]} * 1024" | bc | sed -e 's/^\./0./g')
            local writeB=$(echo "${diskStatB[5]} * 1024" | bc | sed -e 's/^\./0./g')
            local readDiff=$((${readB%.*} - ${readA%.*}))
            local writeDiff=$((${writeB%.*} - ${writeA%.*}))

            local diskName=$(printf "[ %-5s ]" $(basename ${DISK_LIST[$i]}))
            printDetailTitle "$diskName \\e[38;5;208m$diskUsed / $diskTotal\\e[0m"
            printFixSizeBar $diskUsage $MIN_BAR_SIZE
            local read=$(convertByte2 $readDiff)
            local write=$(convertByte2 $writeDiff)
            printDetailTitle "   \\e[38;5;81m⯆ $write/s\\e[0m  \\e[38;5;203m⯅ $read/s\\e[0m"
            printClear
        done
        printClear
    fi
    printClear
}

printSystemNetwork() {

    if [ -n "$ETH_INTERFACES" ]; then
        printSubTitle "[ Network ]"
        local netStatus1=$(cat /proc/net/dev)
        sleep 1s
        local netStatus2=$(cat /proc/net/dev)
        for i in `seq 0 $((${#ETH_INTERFACES[@]} - 1))`; do

            local ifStatus1=($(echo -e "$netStatus1" | grep ${ETH_INTERFACES[$i]} | tr -s ' '))
            local ifStatus2=($(echo -e "$netStatus2" | grep ${ETH_INTERFACES[$i]} | tr -s ' '))
            local download=$((${ifStatus2[1]} - ${ifStatus1[1]}))
            local upload=$((${ifStatus2[9]} - ${ifStatus1[9]}))
            local linkStatus=$(ethtool ${ETH_INTERFACES[$i]} 2>/dev/null | grep --color=auto 'Link detected' | cut -d: -f 2)
            if [ $linkStatus = "yes" ]; then
                linkStatus="\\e[38;5;10m●\\e[0m"
            else
                linkStatus="○"
            fi
            printDetailTitle "[ $linkStatus "
            printDetailTitle "${ETH_INTERFACES[$i]} ] "
            download=$(convertByte2 $download)
            upload=$(convertByte2 $upload)
            printDetailTitle "\\e[38;5;81m⯆ $download/s\\e[0m"
            printDetailTitle "  \\e[38;5;203m⯅ $upload/s\\e[0m"
            printClear
        done
    fi
    printClear
}

printUpsStatus() {
    if (type apcaccess > /dev/null 2>&1); then
        printSubTitle "[ UPS ]"
        local upsStatusAll=$(apcaccess)
        local model="[$(echo "$upsStatusAll" | grep MODEL | cut -d: -f2)]"
        local upsStatus="$(echo "$upsStatusAll" | grep STATUS | cut -d: -f2|xargs)"
        local color="\\e[38;5;197m"
        if [ "$upsStatus" = "ONLINE" ]; then
            color="\\e[38;5;10m"
        fi
        printDetailTitle "$model $color$upsStatus\\e[0m"
    fi
}

printSystemStatus() {
    printTitle "SYSTEM"
    local tmpFiles=($TEMP_FILE_PATH"/system_host" \
            $TEMP_FILE_PATH"/system_load_average" \
            $TEMP_FILE_PATH"/sytem_cpu" \
            $TEMP_FILE_PATH"/system_memory" \
            $TEMP_FILE_PATH"/system_disk" \
            $TEMP_FILE_PATH"/system_network" \
            $TEMP_FILE_PATH"/system_ups")
    local pidsSystem=()

    {
        BUFFER_NAME="SYSTEM_BUFFER_HOST"
        printSystemHost
        echoBuffer > ${tmpFiles[0]}
    }&
    pidsSystem[0]=$!
    {
        BUFFER_NAME="SYSTEM_BUFFER_LOAD_AVERAGE"
        printSystemLoadAverage
        echoBuffer > ${tmpFiles[1]}
    }&
    pidsSystem[1]=$!
    {
        BUFFER_NAME="SYSTEM_BUFFER_CPU"
        printSystemCpu
        echoBuffer > ${tmpFiles[2]}
    }&
    pidsSystem[2]=$!
    {
        BUFFER_NAME="SYSTEM_BUFFER_MEMORY"
        printSystemMemory
        echoBuffer > ${tmpFiles[3]}
    }&
    pidsSystem[3]=$!
    {
        BUFFER_NAME="SYSTEM_BUFFER_DISK"
        printSystemDisk
        echoBuffer > ${tmpFiles[4]}
    }&
    pidsSystem[4]=$!
    {
        BUFFER_NAME="SYSTEM_BUFFER_NETWORK"
        printSystemNetwork
        echoBuffer > ${tmpFiles[5]}
    }&
    pidsSystem[5]=$!
    {
        BUFFER_NAME="SYSTEM_BUFFER_UPS"
        printUpsStatus
        echoBuffer > ${tmpFiles[6]}
    }&
    pidsSystem[6]=$!

    wait ${pidsSystem[@]}
    for f in ${tmpFiles[@]}; do
        prettyPrint "$(cat $f)"
        prettyPrintNoReturn '\\n'
    done
}
#############################################################################################################

# PROCESS STATUS

#############################################################################################################

printProcess() {
    printTitle "PROCESS"
    local maxPid=$(cat /proc/sys/kernel/pid_max)
    local process=$(\ps ax -o pid,pcpu,pmem,cmd  --sort pcpu | tac | head -n 10 | grep -v "^\s\?[0-9]\{1,${#maxPid}\}\s\+0\.0")

    local cols=$(($(tput cols) - 5))
    local header=$(printf "|%$((${#maxPid} + 2))s%8s%8s" "PID" "%CPU" "%MEM")
    local cmdLength=$(($cols - ${#header} - 5))
    local header=$(printf "%s    %-${cmdLength}s  |" "$header" "CMD")
    local lineLength=$((${#header} - 2))
    local frame=`printf -- -"%.s" $(eval echo {1..$cols})`
    local divider=`printf -- ="%.s" $(eval echo {1..$cols})`
    prettyPrint "+$frame+"
    prettyPrint "$header"
    prettyPrint "|$divider|"
    while read line; do
        local tmp=($line)
        local pLine=$(printf "|%$((${#maxPid} + 2))s%7s%%%7s%%    %-${cmdLength}s  |\n" ${tmp[0]} ${tmp[1]} ${tmp[2]} ${tmp[3]:0:$cmdLength})
        prettyPrint "$pLine"
    done <<-END
	$process
	END
    #ハードタブ必須
    prettyPrint "+$frame+"
}

#############################################################################################################

# MAIN LOOP

#############################################################################################################
mainloop() {
    clear
    #hide cursor
    echo -e "\e[?25l"
    trap 'echo -e "\e[?25h" && clear && rm -rf $TEMP_FILE_PATH' EXIT

    while :
    do
        local pids=()
        {
            BUFFER_NAME="SYSTEM_BUFFER"
            printSystemStatus
            echoBuffer > $TEMP_FILE_PATH"/system"
        }&

        pids[$!]=$!
        {
            BUFFER_NAME="GPU_BUFFER"
            printGpuStatus
            echoBuffer > $TEMP_FILE_PATH"/gpu"
        }&

        pids[$!]=$!
        {
            BUFFER_NAME="PROCESS_BUFFER"
            printProcess
            echoBuffer > $TEMP_FILE_PATH"/process"
        }&

        wait ${pids[@]}
        render $TEMP_FILE_PATH"/system" $TEMP_FILE_PATH"/gpu" $TEMP_FILE_PATH"/process"
        sleep $SLEEP_TIME
   done
}





# Entory Point #####################

mainloop

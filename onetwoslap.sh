#!/bin/bash 

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"

function banner {
echo "Inspired by superkojiman's onetwopunch...                                         "
echo "one two SLAP!                                                                     "
echo "lmao                                                                              "
echo "onetwopunch using masscan and different default nmap arguments                    "
echo "useful for non-tap VPN interfaces                                                 "
echo "                                                                                  "
echo "                                                                   by s4dp4nd4    "
echo ""
}

function usage {
    echo "Usage: $0 -t targets.txt [-p tcp/udp/all] [-i interface] [-n nmap-options] [-h]"
    echo "       -h: Help"
    echo "       -t: File containing ip addresses to scan. This option is required."
    echo "       -p: Protocol. Defaults to tcp"
    echo "       -i: Network interface. Defaults to eth0"
    echo "       -n: NMAP options (-A, -O, etc). Defaults to no options."
}


banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH   environment"
    exit 1
fi

if [[ -z $(which masscan) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find masscan. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $1 ]]; then
    usage
    exit 0
fi

# commonly used default options
proto="tcp"
iface="eth0"
nmap_opt="-sV"
targets=""

while getopts "p:i:t:n:h" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) targets=${OPTARG};;
        n) nmap_opt=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [[ -z $targets ]]; then
    echo "[!] No target file provided"
    usage
    exit 1
fi

if [[ ${proto} != "tcp" && ${proto} != "udp" && ${proto} != "all" ]]; then
    echo "[!] Unsupported protocol"
    usage
    exit 1
fi

echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
echo -e "${BLUE}[+]${RESET} Targets  : ${targets}"

# backup any old scans before we start a new one
log_dir="${HOME}/.onetwoslap"
mkdir -p "${log_dir}/backup/"
if [[ -d "${log_dir}/ndir/" ]]; then 
    mv "${log_dir}/ndir/" "${log_dir}/backup/ndir-$(date "+%Y%m%d-%H%M%S")/"
fi
if [[ -d "${log_dir}/udir/" ]]; then 
    mv "${log_dir}/udir/" "${log_dir}/backup/udir-$(date "+%Y%m%d-%H%M%S")/"
fi 

rm -rf "${log_dir}/ndir/"
mkdir -p "${log_dir}/ndir/"
rm -rf "${log_dir}/udir/"
mkdir -p "${log_dir}/udir/"

while read ip; do
    log_ip=$(echo ${ip} | sed 's/\//-/g')
    echo -e "${BLUE}[+]${RESET} Scanning $ip for $proto ports..."

    # masscan identifies all open TCP ports
    if [[ $proto == "tcp" || $proto == "all" ]]; then 
        echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using masscan..."
        echo -e "${BLUE}[+]${RESET} masscan -e ${iface} -p1-65535 ${ip} --rate=900 --wait 0 --output-format list --output-file ${log_dir}/udir/${log_ip}-tcp.txt"
        masscan -e ${iface} -p1-65535 ${ip} --rate=900 --wait 0 --output-format list --output-file ${log_dir}/udir/${log_ip}-tcp.txt
        ports=$(cat "${log_dir}/udir/${log_ip}-tcp.txt" | grep open | cut -d" " -f3 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then 
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sC -oX ${log_dir}/ndir/${log_ip}-tcp.xml -oG ${log_dir}/ndir/${log_ip}-tcp.grep -p ${ports} ${ip}"
            nmap -e ${iface} ${nmap_opt} -sC -oX ${log_dir}/ndir/${log_ip}-tcp.xml -oG ${log_dir}/ndir/${log_ip}-tcp.grep -p ${ports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No TCP ports found"
        fi
    fi

    # masscan identifies all open UDP ports
    if [[ $proto == "udp" || $proto == "all" ]]; then  
        echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using masscan..."
        echo -e "${BLUE}[+]${RESET} masscan -e ${iface} -pU:1-65535 ${ip} --rate=900 --wait 0 --output-format list --output-file ${log_dir}/udir/${log_ip}-udp.txt"
        masscan -e ${iface} -pU:1-65535 ${ip} --rate=900 --wait 0 --output-format list --output-file ${log_dir}/udir/${log_ip}-udp.txt
        ports=$(cat "${log_dir}/udir/${log_ip}-udp.txt" | grep open | cut -d" " -f3 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sU -sC -oX ${log_dir}/ndir/${log_ip}-udp.xml -oG ${log_dir}/ndir/${log_ip}-udp.grep -p ${ports} ${ip}"
            nmap -e ${iface} ${nmap_opt} -sU -sC -oX ${log_dir}/ndir/${log_ip}-udp.xml -oG ${log_dir}/ndir/${log_ip}-udp.grep -p ${ports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No UDP ports found"
        fi
    fi
done < ${targets}

echo -e "${BLUE}[+]${RESET} Scans completed"
echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"



#!/bin/bash
All_Path=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export All_Path

#脚本版本
Shell_Version="1.0.0"
#定义输出
Font_Green="\033[32m"
Font_Red="\033[31m"
Font_Blue="\033[34m"
Font_Yellow="\033[33m"
Back_Green="\033[42;37m"
Back_Red="\033[41;37m"
Font_None="\033[0m"
Info="${Font_Blue}[信息]${Font_None}"
Tip="${Font_Yellow}[注意]${Font_None}"
Error="${Font_Red}[错误]${Font_None}"
Success="${Font_Green}[信息]${Font_None}"
Path_Dir="/etc/ehco"
Path_Conf="{$Path_Dir}/config.json"
Path_Log="{$Path_Dir}/log.txt"
if [ ! -d /usr/lib/systemd/system ]; then
	Path_Ctl="/etc/systemd/system/ehco.service"
else
	Path_Ctl="/usr/lib/systemd/system/ehco.service"
fi

#Root用户
Get_User=$(env | grep USER | cut -d "=" -f 2)
if [ $EUID -ne 0 ] || [ ${Get_User} != "root" ]; then
	echo -e "{$Error} 请使用Root账户运行该脚本"
	exit 1
fi

#
function Check_Status() {
	Get_Pid=$(ps -ef| grep "ehco"| grep -v grep| grep -v ".sh"| grep -v "init.d"| grep -v "service"| awk '{print $2}')
}

#检查系统
function Check_System() {
	if [[ -f /etc/redhat-release ]]; then
		Release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		Release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		Release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		Release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		Release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		Release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		Release="centos"
	fi
	Bit=$(uname -m)
	if test "$Bit" = "armv8l"; then
		Bit="arm64"
	elif test "$Bit" = "aarch64"; then
		Bit="arm64"
	elif test "$Bit" = "x86_64"; then
		Bit="amd64"
	else
		echo -e "${Error} 抱歉 目前Ehco脚本仅支持x86_64,armv8l和aarch64架构"
		exit 1
	fi
}

#安装依赖
function Install_Dependence() {
	if [[ ${Release} == "centos" ]]; then
		yum update
		yum install -y gzip wget curl crontabs vixie-cron net-tools jq
	else
		apt-get update
		apt-get install -y gzip wget curl cron net-tools jq
	fi
}

#安装Ehco
function Install_Ehco() {
	Install_Dependence
	if [ ! -f "/usr/bin/ehco" ]; then
		echo -e "${Info} 开始安装Ehco"
		Ehco_NewVer=$(wget -qO- https://github-api.weifeng.workers.dev/repos/Ehco1996/ehco/releases| grep "tag_name"| head -n 1| awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g;s/v//g')
		mkdir /etc/ehco
		if [[ ${Bit} == "amd64" ]]; then
			wget -N --no-check-certificate "https://github.weifeng.workers.dev/https://github.com/Ehco1996/ehco/releases/download/v${Ehco_NewVer}/ehco_${Ehco_NewVer}_linux_amd64" -O ehco && chmod +x ehco && mv ehco ${Path_Dir}/ehco 
		elif [[ ${Bit} == "arm64" ]]; then
			wget -N --no-check-certificate "https://github.weifeng.workers.dev/https://github.com/Ehco1996/ehco/releases/download/v${Ehco_NewVer}/ehco_${Ehco_NewVer}_linux_arm64" -O ehco && chmod +x ehco && mv ehco ${Path_Dir}/ehco
		else
			echo "${Error} 与Github交互失败，安装Ehco失败，即将终止运行脚本"
			sleep 3s
			exit 1
		fi
		ln -s ${Path_Dir}/ehco /usr/bin/ehco
		Download_Config
	fi
	echo -e "${Success} Ehco已经安装完毕，现在开始配置并启动Ehco服务"
	sleep 3s
	Init_Ehco
}

#下载配置文件
function Download_Config() {
	if [ ! -d ${Path_Dir} ]; then
		mkdir ${Path_Dir}
		touch ${Path_Dir}/config.json
	fi
	wget -N --no-check-certificate "https://github.weifeng.workers.dev/https://github.com/wf-nb/EasyEhco/blob/latest/config.json" -O config.json && chmod +x config.json && mv config.json ${Path_Dir}/config.json
	wget -N --no-check-certificate "https://github.weifeng.workers.dev/https://github.com/wf-nb/EasyEhco/blob/latest/config.json.example" -O config.json.example && chmod +x config.json.example && mv config.json.example ${Path_Dir}/config.json.example
}

#配置Ehco
function Init_Ehco() {
	if [ ! -d ${Path_Dir} ]; then
		mkdir ${Path_Dir}
	fi
	echo "
[Unit]
Description=Ehco
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
LimitNOFILE=32767 
Type=simple
User=root
Restart=on-failure
RestartSec=3s
DynamicUser=true
ExecStart=/usr/bin/ehco -c /etc/ehco/config.json

[Install]
WantedBy=multi-user.target" > ehco.service
	mv ehco.service ${Path_Ctl}
	systemctl daemon-reload
	systemctl start ehco
	systemctl enable ehco
	echo -e "${Success} 初始化Ehco成功，Ehco正在运行"
	sleep 3s
	Show_Menu
}

#更新Ehco
function Update_Ehco() {
	if [ ! -f "/usr/bin/ehco" ]; then
		echo -e "${Error} 未安装Ehco 正在返回主菜单"
		Show_Menu
	else
		echo -e "${Info} 检测Ehco更新中"
		Ehco_Version=$(ehco -v | awk -F " " '{print $3}')
		Ehco_NewVer=$(wget -qO- https://github-api.weifeng.workers.dev/repos/Ehco1996/ehco/releases| grep "tag_name"| head -n 1| awk -F ":" '{print $2}'| sed 's/\"//g;s/,//g;s/ //g;s/v//g')
		if [[ ${Ehco_NewVer} == ${Ehco_Version} ]]; then
			echo -e "${Info} 本地Ehco已是最新版本，无需更新，即将返回主菜单"
			sleep 3s
			Show_Menu
		else
			if [[ ${Bit} == "amd64" ]]; then
				rm -rf ${Path_Dir}/ehco
				wget -N --no-check-certificate "https://github.weifeng.workers.dev/https://github.com/Ehco1996/ehco/releases/download/v${Ehco_NewVer}/ehco_${Ehco_NewVer}_linux_amd64" -O ehco && chmod +x ehco && mv ehco ${Path_Dir}/ehco 
			elif [[ ${Bit} == "arm64" ]]; then
				rm -rf ${Path_Dir}/ehco
				wget -N --no-check-certificate "https://github.weifeng.workers.dev/https://github.com/Ehco1996/ehco/releases/download/v${Ehco_NewVer}/ehco_${Ehco_NewVer}_linux_arm64" -O ehco && chmod +x ehco && mv ehco ${Path_Dir}/ehco
			else
				echo "${Error} 与Github交互失败，更新Ehco失败，请检查网络设置"
				exit 1
			fi
		fi
		ln -s ${Path_Dir}/ehco /usr/bin/ehco
		echo -e "${Success} Ehco更新完毕，正在重新启动Ehco服务"
		systemctl restart ehco
		sleep 3s
		echo -e "${Success} 重新启动Ehco服务完毕，即将返回主菜单"
		sleep 3s
		Show_Menu
	fi
}

#卸载Ehco
function Uninstall_Ehco() {
	if test -o /usr/bin/ehco -o ${Path_Ctl} -o ${Path_Dir}/config.json;then
		systemctl stop ehco.service
		systemctl disable ehco.service
		rm -rf /usr/bin/ehco
		rm -rf ${Path_Ctl}
		rm -rf ${Path_Dir}/ehco
		rm -rf ${Path_Dir}/config.json
		echo -e "${Success} 成功卸载 Ehco "
		sleep 3s
		Show_Menu
	else
		echo -e "${Error} 未安装 Ehco"
		sleep 3s
		Show_Menu
	fi
}

#启动Ehco
function Start_Ehco() {
	systemctl start ehco
	echo -e "${Success} 成功启动 Ehco"
	sleep 3s
	Show_Menu
}

#停止Ehco
function Stop_Ehco() {
	systemctl stop ehco
	echo -e "${Success} 成功停止 Ehco"
	sleep 3s
	Show_Menu
}

#重启Ehco
function Restart_Ehco() {
	systemctl restart ehco
	echo -e "${Success} 成功重启 Ehco"
	sleep 3s
	Show_Menu
}

#切换模式
function Config_Mode() {
	if [ ! -n "$1" ]; then
		echo -e "请问您要切换至哪种模式: "
		echo -e "-----------------------------------"
		echo -e "[1]  本地配置文件模式"
		echo -e "说明: 使用存放于/etc/echo/config.json的配置文件"
		echo -e "-----------------------------------"
		echo -e "[2]  远程配置文件模式"
		echo -e "说明: 用于对接Api使用，获取远程配置文件"
		echo -e "     选择此模式意味着你需要有一个网站存放配置文件"
		echo -e "-----------------------------------"
		read -p "请选择: " Read_Mode
		if [ "$Read_Mode" == "1" ]; then
			Config_Mode local
		elif [ "$Read_Mode" == "2" ]; then
			read -p "请输入远程配置文件URL: " Read_Url
			if [ ! -n "$Read_Url" ]; then
				echo -e "${Error} 未输入远程配置文件URL"
				exit 1
			fi
			Config_Mode remote "$Read_Url"
		else
			echo -e "${Error} 输入错误"
			exit 1
		fi
	else
		if test "$1" = "local"; then
			if [ ! -d ${Path_Dir} ]; then
				mkdir ${Path_Dir}
				touch /etc/ehco/config.json
			fi
			echo "
[Unit]
Description=Ehco
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
LimitNOFILE=32767 
Type=simple
User=root
Restart=on-failure
RestartSec=3s
DynamicUser=true
ExecStart=/usr/bin/ehco -c /etc/ehco/config.json

[Install]
WantedBy=multi-user.target" > ehco.service
			mv ehco.service ${Path_Ctl}
			systemctl daemon-reload
			systemctl start ehco
			systemctl enable ehco
			echo -e "${Success} 成功切换为本地配置文件模式"
			exit 1
		elif test "$1" = "remote"; then
			if [ ! -d ${Path_Dir} ]; then
				mkdir ${Path_Dir}
			fi
			echo "
[Unit]
Description=Ehco
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
LimitNOFILE=32767 
Type=simple
User=root
Restart=on-failure
RestartSec=3s
DynamicUser=true
ExecStart=/usr/bin/ehco -c $2

[Install]
WantedBy=multi-user.target" > ehco.service
			mv ehco.service ${Path_Ctl}
			systemctl daemon-reload
			systemctl start ehco
			systemctl enable ehco
			echo -e "${Success} 成功切换为远程配置文件模式"
			exit 1
		else
			echo -e "${Error} 切换配置文件模式失败"
			exit 1
		fi
	fi
}

#获取模式
function Get_Mode() {
	Get_Config_Path=$(sed -n '14 p' ${Path_Ctl} | awk -F " " '{print $3}')
	if test "$Get_Config_Path" = "/etc/ehco/config.json"; then
		Get_Config_Mode="local"
	else
		Get_Config_Mode="remote"
	fi
}

#配置文件
function Get_Config() {
	echo -e "${Info} 正在获取配置文件模式"
	Get_Mode
	sleep 1s
	if test "$Get_Config_Mode" = "local"; then
		echo -e "${Info} 当前模式为本地配置文件模式"
		echo -e "${Info} 获取本地配置文件中"
		Get_Config_Text=$(cat "$Get_Config_Path" | jq -r '.')
	elif test "$Get_Config_Mode" = "remote"; then
		echo -e "${Info} 当前模式为远程配置文件模式"
		echo -e "${Info} 获取远程配置文件中"
		Get_Config_Text=$(curl -L -s "$Get_Config_Path" | jq -r '.')
	else
		echo -e "${Error} 未检测到配置文件模式"
		exit 1
	fi
	Get_Config_Rules=$(echo "$Get_Config_Text" | jq -r '.relay_configs')
}

#规则列表
function Show_Rule() {
	Get_Config
	sleep 2s
	echo -e "                         规则列表                        "
	echo -e "----------------------------------------------------------------------------------"
	echo -e "序号|方法\t|本地端口|tcp中转地址 \t| udp中转地址"
	echo -e "----------------------------------------------------------------------------------"
	Count_Rules=$(echo $Get_Config_Rules | jq -r ".[]|\"\(.listen)\"" | wc -l)
	for((i=0;i<${Count_Rules};i++));do
		#Get_Rule_InfoA=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.label)\"")
		Get_Rule_InfoA=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.listen)\"" | awk -F ":" '{print $2}')
		Get_Rule_InfoB=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.listen_type)\"")
		Get_Rule_InfoC=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.transport_type)\"")
		Get_Rule_InfoDs=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.tcp_remotes)\"")
		Get_Rule_InfoEs=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.udp_remotes)\"")
		if [ "$Get_Rule_InfoB" == "raw" ] && [ "$Get_Rule_InfoC" == "raw" ]; then
			Relay_Mode="无加密中转"
		elif [ "$Get_Rule_InfoB" == "raw" ] && [ "$Get_Rule_InfoC" != "raw" ]; then
			Relay_Mode="$Get_Rule_InfoC隧道加密"
		elif [ "$Get_Rule_InfoB" != "raw" ] && [ "$Get_Rule_InfoC" == "raw" ]; then
			Relay_Mode="$Get_Rule_InfoB隧道落地"
		else
			Relay_Mode="未知加密方式"
		fi
		if [ "$Get_Rule_InfoDs" != "null" ]; then
			Count_Tcp_Remotes=$(echo $Get_Rule_InfoDs | jq -r ".[]" | wc -l)
			for((j=0;j<${Count_Tcp_Remotes};j++));do
				Get_Rule_InfoD=$(echo "$Get_Rule_InfoDs" | jq -r ".[$j]")
				Tcp_Remotes="$Tcp_Remotes $Get_Rule_InfoD"
			done
		fi
		if [ "$Get_Rule_InfoEs" != "null" ]; then
			Count_Udp_Remotes=$(echo $Get_Rule_InfoEs | jq -r ".[]" | wc -l)
			for((k=0;k<${Count_Udp_Remotes};k++));do
				Get_Rule_InfoE=$(echo "$Get_Rule_InfoEs" | jq -r ".[$k]")
				Udp_Remotes="$Udp_Remotes $Get_Rule_InfoE"
			done
		fi
		echo -e "$i |$Relay_Mode\t|$Get_Rule_InfoA\t|$Tcp_Remotes \t| $Udp_Remotes"
		#printf "%s  %10s   %s      %s %30s  |  %s\n" "$i" "${Get_Rule_InfoA:0:10}" "${Relay_Mode:0:10}" "${Get_Rule_InfoB:0:10}" "${Tcp_Remotes:0:30}" "${Udp_Remotes:0:30}"
		Tcp_Remotes=""
		Udp_Remotes=""
	done
	echo -e "----------------------------------------------------------------------------------"
	echo -e "ws（较好的稳定性及较快的传输速率延时也不高）\nwss（不错的稳定性及较快的传输速率但延时较高）\nmwss（极高的稳定性且延时最低但传输速率最差）"
	echo -e "----------------------------------------------------------------------------------"
}

#添加到本地配置文件
function Add_Config() {
	if [ ! -z $1 ] && [ ! -z $2 ] && [ ! -z $3 ] && [ ! -z $4 ] && [ ! -z $5 ] && [ ! -z $6 ]; then
		if [ ! -z $7 ] && [ ! -z $8 ]; then
			Rule_Json="{\"listen\":\"$1:$2\",\"listen_type\":\"$3\",\"transport_type\":\"$4\",\"tcp_remotes\":[\"$5:$6\"],\"udp_remotes\":[\"$7:$8\"]}"
		else
			Rule_Json="{\"listen\":\"$1:$2\",\"listen_type\":\"$3\",\"transport_type\":\"$4\",\"tcp_remotes\":[\"$5:$6\"],\"udp_remotes\":[]}"
		fi
		Rule_Result=$(echo "$Get_Config_Text" | jq --argjson Rule_Arr "$Rule_Json" '.relay_configs += [$Rule_Arr]')
		if [ ! -z "$Rule_Result" ]; then
			echo $Rule_Result > $Path_Dir/config.json
			systemctl restart ehco
			echo -e "${Success} 添加转发规则成功，即将返回主菜单"
			sleep 3s
			Show_Menu
		else
			echo -e "${Error} 添加转发规则失败，请检查错误信息"
			exit 1
		fi
	else
		echo -e "${Error} 未传入配置参数"
		exit 1
	fi
}

#tcp/udp无加密转发
function Add_Relay() {
	echo -e "当前转发模式：tcp/udp无加密转发"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个端口呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要转发至哪个远程服务器IP或域名呢？"
	echo -e "注: 既可以是[远程机器/当前机器]的公网IP，也可是以本地回环IP（即127.0.0.1）"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要转发至远程服务器的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "raw" "raw" "$Read_Remote_IP" "$Read_Remote_Port" "$Read_Remote_IP" "$Read_Remote_Port"
}

#ws隧道加密转发
function Add_Encryptws() {
	echo -e "当前转发模式：ws隧道加密转发"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要加密哪个端口收到的流量呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要将[$Read_Local_Port]加密流量转发至哪个远程服务器IP或域名呢？"
	echo -e "注: 请确认已在远程服务器上部署了隧道解密端"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要将[$Read_Local_Port]加密流量转发至[$Read_Remote_IP]的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "raw" "ws" "ws://$Read_Remote_IP" "$Read_Remote_Port" "$Read_Remote_IP" "$Read_Remote_Port"
}

#wss隧道加密转发
function Add_Encryptwss() {
	echo -e "当前转发模式：wss隧道加密转发"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要加密哪个端口收到的流量呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要将[$Read_Local_Port]加密流量转发至哪个远程服务器IP或域名呢？"
	echo -e "注: 请确认已在远程服务器上部署了隧道解密端"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要将[$Read_Local_Port]加密流量转发至[$Read_Remote_IP]的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "raw" "wss" "wss://$Read_Remote_IP" "$Read_Remote_Port" "$Read_Remote_IP" "$Read_Remote_Port"
}

#mwss隧道加密转发
function Add_Encryptmwss() {
	echo -e "当前转发模式：mwss隧道加密转发"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要加密哪个端口收到的流量呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要将[$Read_Local_Port]加密流量转发至哪个远程服务器IP或域名呢？"
	echo -e "注: 请确认已在远程服务器上部署了隧道解密端"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要将[$Read_Local_Port]加密流量转发至[$Read_Remote_IP]的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "raw" "mwss" "mwss://$Read_Remote_IP" "$Read_Remote_Port" "$Read_Remote_IP" "$Read_Remote_Port"
}

#ws隧道解密落地
function Add_Decryptws() {
	echo -e "当前转发模式：ws隧道解密落地"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要解密哪个端口收到的流量呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问你要将本机从[$Read_Local_Port]接收到的流量转发向哪个IP或域名？"
	echo -e "注: IP既可以是[远程机器/当前机器]的公网IP, 也可是以本地回环IP（即127.0.0.1）"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问你要将本机从[$Read_Local_Port]接收到的流量转发向[$Read_Remote_IP]的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "ws" "raw" "$Read_Remote_IP" "$Read_Remote_Port"
}

#wss隧道解密落地
function Add_Decryptwss() {
	echo -e "当前转发模式：wss隧道解密落地"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要解密哪个端口收到的流量呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问你要将本机从[$Read_Local_Port]接收到的流量转发向哪个IP或域名？"
	echo -e "注: IP既可以是[远程机器/当前机器]的公网IP, 也可是以本地回环IP（即127.0.0.1）"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问你要将本机从[$Read_Local_Port]接收到的流量转发向[$Read_Remote_IP]的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "wss" "raw" "$Read_Remote_IP" "$Read_Remote_Port"
}

#mwss隧道解密落地
function Add_Decryptmwss() {
	echo -e "当前转发模式：mwss隧道解密落地"
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要侦听哪个IP呢？"
	echo -e "注: IP请填写所需的网卡IP, 全网口侦听请输入0.0.0.0"
	read -p "请输入 默认127.0.0.1 " Read_Local_IP
	if [ ! -n "$Read_Local_IP" ]; then
		Read_Local_IP="127.0.0.1"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问需要解密哪个端口收到的流量呢？"
	read -p "请输入 默认23333 " Read_Local_Port
	if [ ! -n "$Read_Local_Port" ]; then
		Read_Local_Port="23333"
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问你要将本机从[$Read_Local_Port]接收到的流量转发向哪个IP或域名？"
	echo -e "注: IP既可以是[远程机器/当前机器]的公网IP, 也可是以本地回环IP（即127.0.0.1）"
	read -p "请输入 " Read_Remote_IP
	if [ ! -n "$Read_Remote_IP" ]; then
		echo -e "${Error} 未输入远程服务器地址"
		exit 1
	fi
    echo -e "------------------------------------------------------------------"
	echo -e "请问你要将本机从[$Read_Local_Port]接收到的流量转发向[$Read_Remote_IP]的哪个端口呢？"
	read -p "请输入 " Read_Remote_Port
	if [ ! -n "$Read_Remote_Port" ]; then
		echo -e "${Error} 未输入远程服务器端口"
		exit 1
	fi
	echo -e "${Info} 正在初始化添加转发"
	echo -e "${Info} 检测端口占用"
	sleep 1s
	Check_Port "$Read_Local_Port"
	Add_Config "$Read_Local_IP" "$Read_Local_Port" "mwss" "raw" "$Read_Remote_IP" "$Read_Remote_Port"
}

#检测端口
function Check_Port() {
	if hash netstat 2>/dev/null; then
		if [ ! -n "$1" ]; then
			echo -e "${Error} 未传入端口"
			exit 1
		else
			Get_Port_Info=$(netstat -nap | grep LISTEN | grep "$1")
			if [ ! -z "$Get_Port_Info" ]; then
				echo -e "${Error} 端口[$1]已被占用"
				exit 1
			fi
		fi
	else
		echo -e "${Error} Netstat组件丢失，请手动安装net-tools后重新运行脚本"
		exit 1
	fi
}

#添加规则
function Add_Rule() {
	Get_Mode
	if test "$Get_Config_Mode" = "local"; then
		Get_Config
	elif test "$Get_Config_Mode" = "remote"; then
		echo -e "${Error} 检测到当前模式为远程配置文件，无法使用该脚本进行添加规则"
		exit 1
	else
		echo -e "${Error} 未检测到配置文件模式"
		exit 1
	fi
	sleep 2s
	echo -e "请选择转发模式："
	echo -e "-----------------------------------"
	echo -e "[1]  tcp/udp无加密转发"
	echo -e "说明：适用于转发加密级别高的服务，一般设置在国内中转机上"
	echo -e "-----------------------------------"
	echo -e "[2]  w s 隧道加密转发"
	echo -e "说明：用于转发原本加密等级较低的流量，一般设置在国内中转机上"
	echo -e "      较好的稳定性及较快的传输速率延时也不高"
	echo -e "-----------------------------------"
	echo -e "[3]  wss 隧道加密转发"
	echo -e "说明：用于转发原本加密等级较低的流量，一般设置在国内中转机上"
	echo -e "      不错的稳定性及较快的传输速率但延时较高"
	echo -e "-----------------------------------"
	echo -e "[4]  mwss隧道加密转发"
	echo -e "说明：用于转发原本加密等级较低的流量，一般设置在国内中转机上"
	echo -e "      极高的稳定性且延时最低但传输速率最差"
	echo -e "-----------------------------------"
	echo -e "[5]  w s 隧道解密落地"
	echo -e "说明：对转发进入本机端口的流量进行解密并转发给低级别加密代理"
	echo -e "      一般设置在用于接收中转流量的国外机器上"
	echo -e "-----------------------------------"
	echo -e "[6]  wss 隧道解密落地"
	echo -e "说明：对转发进入本机端口的流量进行解密并转发给低级别加密代理"
	echo -e "      一般设置在用于接收中转流量的国外机器上"
	echo -e "-----------------------------------"
	echo -e "[7]  mwss隧道解密落地"
	echo -e "说明：对转发进入本机端口的流量进行解密并转发给低级别加密代理"
	echo -e "      一般设置在用于接收中转流量的国外机器上"
	echo -e "-----------------------------------"
	read -p "请选择: " Read_Mode
	case "$Read_Mode" in
	1)
		Add_Relay
	;;
	2)
		Add_Encryptws
	;;
	3)
		Add_Encryptwss
	;;
	4)
		Add_Encryptmwss
	;;
	5)
		Add_Decryptws
	;;
	6)
		Add_Decryptwss
	;;
	7)
		Add_Decryptmwss
	;;
	*)
		echo "请输入正确数字 [1-7]"
	;;
	esac
}

#删除规则
function Del_Rule() {
	Get_Config
	Count_Rules=$(echo $Get_Config_Rules | jq -r ".[]|\"\(.listen)\"" | wc -l)
	for((i=0;i<${Count_Rules};i++));do
		Get_Rule_InfoA=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.listen)\"")
		Get_Rule_InfoB=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.listen_type)\"")
		Get_Rule_InfoC=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.transport_type)\"")
		Get_Rule_InfoDs=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.tcp_remotes)\"")
		Get_Rule_InfoEs=$(echo "$Get_Config_Rules" | jq -r ".[$i]|\"\(.udp_remotes)\"")
		if [ "$Get_Rule_InfoB" == "raw" ] && [ "$Get_Rule_InfoC" == "raw" ]; then
			Relay_Mode="无加密中转"
		elif [ "$Get_Rule_InfoB" == "raw" ] && [ "$Get_Rule_InfoC" != "raw" ]; then
			Relay_Mode="$Get_Rule_InfoC隧道加密"
		elif [ "$Get_Rule_InfoB" != "raw" ] && [ "$Get_Rule_InfoC" == "raw" ]; then
			Relay_Mode="$Get_Rule_InfoB隧道落地"
		else
			Relay_Mode="未知加密方式"
		fi
		if [ "$Get_Rule_InfoDs" != "null" ]; then
			Count_Tcp_Remotes=$(echo $Get_Rule_InfoDs | jq -r ".[]" | wc -l)
			for((j=0;j<${Count_Tcp_Remotes};j++));do
				Get_Rule_InfoD=$(echo "$Get_Rule_InfoDs" | jq -r ".[$j]")
				Tcp_Remotes="$Tcp_Remotes $Get_Rule_InfoD"
			done
		fi
		if [ "$Get_Rule_InfoEs" != "null" ]; then
			Count_Udp_Remotes=$(echo $Get_Rule_InfoEs | jq -r ".[]" | wc -l)
			for((k=0;k<${Count_Udp_Remotes};k++));do
				Get_Rule_InfoE=$(echo "$Get_Rule_InfoEs" | jq -r ".[$k]")
				Udp_Remotes="$Udp_Remotes $Get_Rule_InfoE"
			done
		fi
		echo -e "$i.$Relay_Mode \t $Get_Rule_InfoA \t->tcp:$Tcp_Remotes \t udp:$Udp_Remotes"
		Tcp_Remotes=""
		Udp_Remotes=""
	done
	read -p "请输入你要删除的规则编号：" Read_Num
	if [ "$Read_Num" -gt "$((Count_Rules-1))" ]; then
		echo -e "${Error} 没有序数为[$Read_Num]的规则"
		exit 1
	fi
	Rule_Json=$(echo $Get_Config_Rules | jq -r ".[$Read_Num]")
	Rule_Result=$(echo "$Get_Config_Text" | jq --argjson Rule_Arr "$Rule_Json" '.relay_configs -= [$Rule_Arr]')
	if [ ! -z "$Rule_Result" ]; then
		echo $Rule_Result > $Path_Dir/config.json
		systemctl restart ehco
		echo -e "${Success} 删除转发规则成功，即将返回主菜单"
		sleep 3s
		Show_Menu
	else
		echo -e "${Error} 删除转发规则失败，请检查错误信息"
		exit 1
	fi
}

#更新脚本
function Update_Shell() {
	echo -e "${Info} 当前版本为 [ ${Shell_Version} ]，开始检测最新版本..."
	Shell_NewVer=$(wget --no-check-certificate -qO- "https://github.weifeng.workers.dev/https://github.com/wf-nb/EasyEhco/blob/latest/ehco.sh"|grep 'Shell_Version="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1)
	[[ -z ${Shell_NewVer} ]] && echo -e "${Error} 检测最新版本失败" && Show_Menu
	if [ $(awk -v Shell_NewVer="$Shell_NewVer" -v Shell_Version="$Shell_Version"  'BEGIN{print(Shell_NewVer>Shell_Version)?"1":"0"}') ]; then
		echo -e "${Info} 发现新版本[ ${Shell_NewVer} ]，是否更新？[Y/n]"
		read -p "(默认: Y):" Read_YN
		[[ -z "${Read_YN}" ]] && Read_YN="Y"
		if [[ ${Read_YN} == [Yy] ]]; then
			wget -N --no-check-certificate https://github.weifeng.workers.dev/https://github.com/wf-nb/EasyEhco/blob/latest/ehco.sh && chmod +x ehco.sh
			echo -e "${Success} 脚本已更新为最新版本[ ${Shell_NewVer} ]"
            sleep 3s
            Show_Menu
		else
			echo -e "${Success} 已取消..."
            sleep 3s
            Show_Menu
		fi
	else
		echo -e "${Info} 当前已是最新版本[ ${Shell_Version} ]"
		sleep 3s
        Show_Menu
	fi
}

#脚本菜单
function Show_Menu() {
	echo -e "          EasyEhco"${Font_red}[${Shell_Version}]${Font_None}"
  ----------- Weifeng -----------
  特性: (1)本脚本采用systemd及Ehco配置文件对Ehco进行管理
        (2)能够在不借助其他工具(如screen)的情况下实现多条转发规则同时生效
        (3)机器reboot后转发不失效
  功能: (1)tcp+udp不加密转发, (2)中转机加密转发, (3)落地机解密对接转发
  帮助文档：https://github.com/wf-nb/EasyEhco
  特别鸣谢：Ehco1996 KANIKIG xOS sjlleo

 ${Font_Green}1.${Font_None} 安装    Ehco
 ${Font_Green}2.${Font_None} 更新    Ehco
 ${Font_Green}3.${Font_None} 卸载    Ehco
————————————
 ${Font_Green}4.${Font_None} 启动    Ehco
 ${Font_Green}5.${Font_None} 停止    Ehco
 ${Font_Green}6.${Font_None} 重启    Ehco
————————————
 ${Font_Green}7.${Font_None} 新增Ehco转发配置
 ${Font_Green}8.${Font_None} 查看现有Ehco配置
 ${Font_Green}9.${Font_None} 删除一则Ehco配置
————————————
 ${Font_Green}10.${Font_None} 初始化Ehco的配置
 ${Font_Green}11.${Font_None} 切换Ehco配置模式
————————————
 ${Font_Green}12.${Font_None} 更新EasyEhco脚本
————————————" && echo
	if [[ -e "${Path_Dir}/ehco" ]]; then
		Check_Status
		if [ ! -z "$Get_Pid" ]; then
			echo -e " 当前状态: Ehco ${Font_Green}已安装${Font_None} 并 ${Font_Green}已启动${Font_None}"
		else
			echo -e " 当前状态: Ehco ${Font_Green}已安装${Font_None} 但 ${Font_Red}未启动${Font_None}"
		fi
	else
		echo -e " 当前状态: Ehco ${Font_Red}未安装${Font_None}"
	fi
	read -e -p " 请输入数字 [1-12]:" Read_Num
	case "$Read_Num" in
	1)
		Install_Ehco
	;;
	2)
		Update_Ehco
	;;
	3)
		Uninstall_Ehco
	;;
	4)
		Start_Ehco
	;;
	5)
		Stop_Ehco
	;;
	6)
		Restart_Ehco
	;;
	7)
		Add_Rule
	;;
	8)
		Show_Rule
	;;
	9)
		Del_Rule
	;;
	10)
		Download_Config
	;;
	11)
		Config_Mode
	;;
	12)
		Update_Shell
	;;
	*)
		echo "请输入正确数字 [1-12]"
	;;
	esac
}

Check_System
Show_Menu
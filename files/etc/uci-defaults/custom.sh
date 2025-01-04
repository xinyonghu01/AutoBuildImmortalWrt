#!/bin/sh

# 设置默认防火墙规则，方便虚拟机首次访问 WebUI
uci set firewall.@zone[1].input='ACCEPT'

# 设置主机名映射，解决安卓原生 TV 无法联网的问题
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"


# 获取 lan 接口设备
lan_iface=$(uci get network.@interface[0].device 2>/dev/null)
wan_iface=$(uci get network.@interface[1].device 2>/dev/null)

# 输出当前网络配置，方便调试
echo "Current Network Config:"
uci show network

# 检查是否找到了 lan 接口和 wan 接口
if [ -z "$lan_iface" ]; then
    echo "Error: Could not determine LAN interface."
    exit 1
fi

if [ -z "$wan_iface" ]; then
    echo "Warning: Could not determine WAN interface. Setting LAN to DHCP."
    uci set network.lan.proto='dhcp'
    uci commit network
    /etc/init.d/network reload
    exit 0
fi

# 判断是否有多个物理网口绑定到 lan
if [ "$lan_iface" != "" ]; then
    lan_devices=$(uci get network.@interface[0].device | sed 's/ /\n/g' | wc -l)
    if [ "$lan_devices" -gt 1 ]; then
        # 如果有多个lan网口，则使用桥接的方式
        uci set network.lan.type='bridge'
        uci delete network.lan.ifname
        devices=$(uci get network.@interface[0].device)
        for dev in $devices
        do
           uci add network interface
           uci set network.@interface[-1].ifname=$dev
           uci set network.@interface[-1].type='bridge-slave'
           uci set network.@interface[-1].master='lan'
           uci delete network.@interface[0].device
        done
        uci set network.lan.proto='static'
        uci set network.lan.ipaddr='192.168.20.1'
        uci set network.lan.netmask='255.255.255.0'

        echo "Multiple LAN interfaces found. Creating a bridge."
    else
        # 只有一个网口，使用默认的DHCP配置
        uci set network.lan.proto='dhcp'
        echo "Single LAN interface found. LAN set to DHCP"
    fi
fi

# 设置 WAN 口为 PPPoE
uci set network.wan.proto='pppoe'
uci set network.wan.username='dl06463297@163'
uci set network.wan.password='123456'
uci commit network
/etc/init.d/network reload

echo "Network configuration updated. WAN is set to PPPoE."

# 设置所有网口可访问网页终端
uci delete ttyd.@ttyd[0].interface

# 设置所有网口可连接 SSH
uci set dropbear.@dropbear[0].Interface=''
uci commit

# 设置编译作者信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by Mid-night"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

exit 0

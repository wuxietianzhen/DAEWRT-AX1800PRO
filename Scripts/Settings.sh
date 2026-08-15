#!/bin/bash

. $(dirname "$(realpath "$0")")/function.sh


# 修改默认主题

sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" \
$(find ./feeds/luci/collections/ -type f -name "Makefile")



# 修改 immortalwrt.lan IP

sed -i \
"s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" \
$(find ./feeds/luci/modules/luci-mod-system/ \
-type f -name "flash.js")



# 添加编译日期

sed -i \
"s/(\(luciversion || ''\))/(\1) + (' \/ DaeWRT-$WRT_DATE')/g" \
$(find ./feeds/luci/modules/luci-mod-status/ \
-type f -name "10_system.js")




# WIFI配置

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ \
-type f -name "*set-wireless.sh" 2>/dev/null)


WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"



if [ -f "$WIFI_SH" ]; then


sed -i \
"s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" \
$WIFI_SH


sed -i \
"s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" \
$WIFI_SH



elif [ -f "$WIFI_UC" ]; then


sed -i \
"s/ssid='.*'/ssid='$WRT_SSID'/g" \
$WIFI_UC


sed -i \
"s/key='.*'/key='$WRT_WORD'/g" \
$WIFI_UC


sed -i \
"s/country='.*'/country='AU'/g" \
$WIFI_UC


sed -i \
"s/encryption='.*'/encryption='psk2+ccmp'/g" \
$WIFI_UC


fi





# 默认IP

CFG_FILE="./package/base-files/files/bin/config_generate"


sed -i \
"s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" \
$CFG_FILE



# 默认hostname

sed -i \
"s/hostname='.*'/hostname='$WRT_NAME'/g" \
$CFG_FILE





# 修复 vlmcsd ccache

vlmcsd_patches="./feeds/packages/net/vlmcsd/patches/"

mkdir -p $vlmcsd_patches

cp -f \
../patches/001-fix_compile_with_ccache.patch \
$vlmcsd_patches






# =========================
# 配置文件追加
# =========================


echo "CONFIG_PACKAGE_luci=y" >> ./.config

echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config


echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config

echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config




# 手动插件输入

if [ -n "$WRT_PACKAGE" ]; then

echo -e "$WRT_PACKAGE" >> ./.config

fi






# =========================
# ZRAM优化
# =========================


echo "CONFIG_PACKAGE_kmod-zram=y" >> ./.config

echo "CONFIG_PACKAGE_zram-swap=y" >> ./.config



mkdir -p ./files/etc/uci-defaults



cat > ./files/etc/uci-defaults/99-zram <<'EOF'

#!/bin/sh


# ZRAM 256MB

uci set system.@system[0].zram_size='256'


# lz4低延迟压缩

uci set system.@system[0].zram_comp_algo='lz4'


# 提高swap积极程度

uci set system.@system[0].zram_swappiness='80'


uci commit system


exit 0

EOF



chmod +x ./files/etc/uci-defaults/99-zram






# =========================
# 高通平台调整
# =========================


DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"



if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then



echo "CONFIG_FEED_nss_packages=n" >> ./.config

echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config



echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config

echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config




# SQM NSS

echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config

echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config





# no wifi调整

if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then


find $DTS_PATH \
-type f \
! -iname '*nowifi*' \
-exec sed -i \
's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +


echo "qualcommax set up nowifi successfully!"


fi



fi

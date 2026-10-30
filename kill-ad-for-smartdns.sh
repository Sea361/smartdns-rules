#!/bin/sh
#=============================================================================
# Script Name : kill-ad-for-smartdns.sh
# Version     : 2.0.0
# Author      : Sea361
# Description : Fetch pre-compiled SmartDNS rules from GitHub & deploy locally
#=============================================================================

# 配置你的 GitHub 用户名与仓库名
GITHUB_USER="Sea361"
GITHUB_REPO="smartdns-rules"
BRANCH="main"

# 定义目录与路径
WORK_DIR="/tmp/etc/smartdns"
UPLOAD_DIR="/tmp/upload"
CONF_FILE="${WORK_DIR}/kill-ad-for-smartdns.conf"
TMP_CONF="/tmp/kill-ad-download.tmp"

# 目标直链与 CDN 备用镜像（防止国内解析/直连 GitHub 失败）
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/kill-ad-for-smartdns.conf"
CDN_URL="https://cdn.jsdelivr.net/gh/${GITHUB_USER}/${GITHUB_REPO}@${BRANCH}/kill-ad-for-smartdns.conf"

mkdir -p "${WORK_DIR}"
mkdir -p "${UPLOAD_DIR}"
rm -f "${TMP_CONF}"

echo "[-] 正在从云端拉取已构建的 SmartDNS 规则..."
curl -fsSL -k --connect-timeout 10 -m 60 "${CDN_URL}" -o "${TMP_CONF}" 2>/dev/null || \
curl -fsSL -k --connect-timeout 10 -m 60 "${RAW_URL}" -o "${TMP_CONF}" 2>/dev/null

if [ ! -s "${TMP_CONF}" ]; then
    echo "[x] 规则下载失败，保留原有配置，退出操作。"
    rm -f "${TMP_CONF}"
    exit 1
fi

# 部署并做软链接
mv -f "${TMP_CONF}" "${CONF_FILE}"
ln -sf "${CONF_FILE}" "/etc/smartdns/address.conf"
ln -sf "${CONF_FILE}" "${UPLOAD_DIR}/kill-ad-for-smartdns.conf"

TOTAL_RULES=$(wc -l < "${CONF_FILE}")
echo "[+] 规则同步成功，当前规则总计: ${TOTAL_RULES} 条"

# 检查 SmartDNS UCI 挂载
echo "[-] 检查 SmartDNS UCI 配置..."
CURRENT_CONF=$(uci get smartdns.@smartdns[0].conf_file 2>/dev/null)

if ! echo "${CURRENT_CONF}" | grep -q "${CONF_FILE}"; then
    echo "[-] 挂载规则文件到 SmartDNS 配置..."
    uci add_list smartdns.@smartdns[0].conf_file="${CONF_FILE}"
    uci commit smartdns
    echo "[+] UCI 配置已更新并提交。"
else
    echo "[+] SmartDNS 已挂载该规则文件。"
fi

# 重载 SmartDNS 服务
echo "[-] 正在生效规则..."
if /etc/init.d/smartdns reload 2>/dev/null; then
    echo "[+] SmartDNS 规则热重载成功！"
else
    /etc/init.d/smartdns restart
    echo "[+] SmartDNS 服务已重启！"
fi

exit 0

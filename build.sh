#!/bin/bash
#=============================================================================
# Script Name : build.sh
# Version     : 2.1.0
# Description : Fetch and merge rules into pure domain-set list & legacy conf
#=============================================================================

set -e

TMP_DOMAINS="smartdns_domains_merge.tmp"
TMP_ANTI="anti-ad-source.tmp"
DOMAIN_SET_FILE="kill-ad-domains.list"
CONF_FILE="kill-ad-for-smartdns.conf"

rm -f "${DOMAIN_SET_FILE}" "${CONF_FILE}" "${TMP_DOMAINS}" "${TMP_ANTI}"

echo "[-] 开始下载并提取广告域名..."

# 1. 下载 anti-ad 并提取纯域名
ANTI_AD_URL1="https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-smartdns.conf"
ANTI_AD_URL2="https://anti-ad.net/anti-ad-smartdns.conf"

curl -fsSL --connect-timeout 15 -m 60 "${ANTI_AD_URL1}" -o "${TMP_ANTI}" || \
curl -fsSL --connect-timeout 15 -m 60 "${ANTI_AD_URL2}" -o "${TMP_ANTI}" || true

if [ -s "${TMP_ANTI}" ]; then
    # 提取 address /domain/# 中的 domain 纯文本
    grep -E '^address /' "${TMP_ANTI}" | sed -E 's|^address /([^/]+)/.*|\1|' >> "${TMP_DOMAINS}"
    rm -f "${TMP_ANTI}"
    echo "[+] anti-ad 域名提取完成"
fi

# 2. 转换 hosts 源并提取纯域名
download_and_extract_hosts() {
    local url="$1"
    local name="$2"
    local tmp_file="hosts_${name}.tmp"

    echo "[-] 正在获取: ${name} ..."
    if curl -fsSL --connect-timeout 15 -m 60 "${url}" -o "${tmp_file}"; then
        grep -vE '^(#|$|;|//)' "${tmp_file}" | \
        awk '{
            for(i=1;i<=NF;i++) {
                if($i ~ /^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$/) {
                    print $i
                }
            }
        }' >> "${TMP_DOMAINS}"
        echo "[+] ${name} 提取完成"
    else
        echo "[!] ${name} 下载失败，跳过"
    fi
    rm -f "${tmp_file}"
}

download_and_extract_hosts "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts" "jdlingyu"
download_and_extract_hosts "https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts.txt" "VeleSila"
download_and_extract_hosts "https://raw.githubusercontent.com/Goooler/1024_hosts/master/hosts" "Goooler"

# 3. 去重生成 domain-set 纯域名文件
if [ -s "${TMP_DOMAINS}" ]; then
    grep -E '^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$' "${TMP_DOMAINS}" | sort -u > "${DOMAIN_SET_FILE}"
    rm -f "${TMP_DOMAINS}"

    TOTAL_RULES=$(wc -l < "${DOMAIN_SET_FILE}")
    echo "[+] 域名集合生成成功: ${DOMAIN_SET_FILE}，有效域名总计: ${TOTAL_RULES} 条"

    # 4. 同时派生传统 conf 文件（每行加 address /domain/#），兼顾老方案
    sed 's|^|address /|; s|$|/#|' "${DOMAIN_SET_FILE}" > "${CONF_FILE}"
    echo "[+] 传统配置文件生成成功: ${CONF_FILE}"
else
    echo "[x] 错误：域名提取结果为空"
    exit 1
fi

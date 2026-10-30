#!/bin/bash
#=============================================================================
# Script Name : build.sh
# Version     : 2.0.0
# Description : Run on GitHub Actions to fetch, convert and merge SmartDNS rules
#=============================================================================

set -e

TMP_MERGE="smartdns_ad_merge.tmp"
TMP_ANTI="anti-ad-source.tmp"
OUTPUT_FILE="kill-ad-for-smartdns.conf"

rm -f "${OUTPUT_FILE}" "${TMP_MERGE}" "${TMP_ANTI}"

echo "[-] 开始下载并处理规则..."

# 1. 下载 anti-ad
ANTI_AD_URL1="https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-smartdns.conf"
ANTI_AD_URL2="https://anti-ad.net/anti-ad-smartdns.conf"

curl -fsSL --connect-timeout 15 -m 60 "${ANTI_AD_URL1}" -o "${TMP_ANTI}" || \
curl -fsSL --connect-timeout 15 -m 60 "${ANTI_AD_URL2}" -o "${TMP_ANTI}" || true

if [ -s "${TMP_ANTI}" ]; then
    grep -E '^address /' "${TMP_ANTI}" > "${TMP_MERGE}"
    rm -f "${TMP_ANTI}"
    echo "[+] anti-ad 规则提取完成"
fi

# 2. 转换 hosts 源
download_and_convert_hosts() {
    local url="$1"
    local name="$2"
    local tmp_file="hosts_${name}.tmp"
    
    echo "[-] 正在获取: ${name} ..."
    if curl -fsSL --connect-timeout 15 -m 60 "${url}" -o "${tmp_file}"; then
        grep -vE '^(#|$|;|//)' "${tmp_file}" | \
        awk '{
            for(i=1;i<=NF;i++) {
                if($i ~ /^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$/) {
                    print "address /"$i"/#"
                }
            }
        }' >> "${TMP_MERGE}"
        echo "[+] ${name} 转换完成"
    else
        echo "[!] ${name} 下载失败，跳过"
    fi
    rm -f "${tmp_file}"
}

download_and_convert_hosts "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts" "jdlingyu"
download_and_convert_hosts "https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts.txt" "VeleSila"
download_and_convert_hosts "https://raw.githubusercontent.com/Goooler/1024_hosts/master/hosts" "Goooler"

# 3. 去重与输出
if [ -s "${TMP_MERGE}" ]; then
    sort -u "${TMP_MERGE}" > "${OUTPUT_FILE}"
    rm -f "${TMP_MERGE}"
    TOTAL_RULES=$(wc -l < "${OUTPUT_FILE}")
    echo "[+] 合并完成，共 ${TOTAL_RULES} 条规则"
else
    echo "[x] 错误：规则生成为空"
    exit 1
fi

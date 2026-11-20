#!/usr/bin/env bash

# 1. Define paths and environment
# Get the directory where the script is located to ensure absolute paths in crontab
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}"
LOG_FILE="/tmp/update_rules.log"

# Create the ruleset directory if it does not exist
mkdir -p "$TARGET_DIR"

echo "========================================="
echo "Update started at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="

# Write log to /tmp/update_rules.log.
# exec > "$LOG_FILE" 2>&1
exec > >(tee "$LOG_FILE") 2>&1
# 2. Define URLs and filenames
files=(
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/gfw.srs gfw.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/google-cn.srs google-cn.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/google.srs google.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geoip/google.srs google-ip.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/google-gemini.srs google-gemini.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geoip/cn.srs cn-ip.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/cn.srs cn.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/geolocation-!cn.srs geolocation-!cn.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/apple.srs apple.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/microsoft.srs microsoft.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/category-games.json category-games.json"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/category-games-cn.srs category-games-cn.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/steam.srs steam.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geoip/netflix.srs netflix-ip.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/netflix.srs netflix.srs"
    "https://raw.githubusercontent.com/privacy-protection-tools/anti-ad.github.io/master/docs/anti-ad-sing-box.srs anti-ad-sing-box.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geoip/telegram.srs telegram-ip.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/telegram.srs telegram.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/blizzard.srs blizzard.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/openai.srs openai.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/github.srs github.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/youtube.srs youtube.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/apple-tvplus.srs apple-tvplus.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/disney.srs disney.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/onedrive.srs onedrive.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/adobe.srs adobe.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/spotify.srs spotify.srs"
    "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/sing/geo/geosite/category-ai-!cn.srs category-ai-!cn.srs"
    
)

# 3. Loop through files and download
for file in "${files[@]}"; do
    URL=$(echo "$file" | awk '{print $1}')
    FILENAME=$(echo "$file" | awk '{print $2}')
    FULL_PATH="${TARGET_DIR}/${FILENAME}"

    if [ -f "$FULL_PATH" ]; then
        echo "[INFO] $FILENAME already exists. Overwriting..."
        # rm -rf $FULL_PATH
    fi

    # Download with a 15-second connection timeout to prevent hanging in cron
    wget -q -O "$FULL_PATH" "$URL"

    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Saved to: $FULL_PATH"
    else
        echo "[ERROR] Failed to download: $URL"
    fi
done

# 4. Restart the service
echo "Restarting homeproxy_plus service..."
/etc/init.d/homeproxy_plus reload

echo "Update finished at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "-----------------------------------------"

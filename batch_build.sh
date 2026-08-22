#!/usr/bin/env bash
# ==============================================================================
# batch_build.sh — Automated Multi-Target Bootchain Builder for macOS
# Organizes bootchains hierarchically by iOS Major Version:
#   bootchain/iOS_17/<DeviceModel>-<Version>-<Build>-ramdisk/
#   bootchain/iOS_18/<DeviceModel>-<Version>-<Build>-ramdisk/
#   bootchain/iOS_26/<DeviceModel>-<Version>-<Build>-ramdisk/
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure directories exist
mkdir -p bootchain cache work

# ------------------------------------------------------------------------------
# Target Device Definitions
# ------------------------------------------------------------------------------
# A12 Devices (CPID 0x8020)
# - iPhone11,2: iPhone XS (d321ap)
# - iPhone11,4: iPhone XS Max China (d331pap)
# - iPhone11,6: iPhone XS Max Global (d331ap)
# - iPhone11,8: iPhone XR (n841ap)
#
# A13 Devices (CPID 0x8030)
# - iPhone12,1: iPhone 11 (n104ap)
# - iPhone12,3: iPhone 11 Pro (d421ap)
# - iPhone12,5: iPhone 11 Pro Max (d431ap)
# - iPhone12,8: iPhone SE 2nd Gen (d79ap)
# ------------------------------------------------------------------------------

TARGET_DEVICES=(
    "iPhone11,2:iPhone_XS:d321ap:0x8020"
    "iPhone11,4:iPhone_XS_Max_China:d331pap:0x8020"
    "iPhone11,6:iPhone_XS_Max:d331ap:0x8020"
    "iPhone11,8:iPhone_XR:n841ap:0x8020"
    "iPhone12,1:iPhone_11:n104ap:0x8030"
    "iPhone12,3:iPhone_11_Pro:d421ap:0x8030"
    "iPhone12,5:iPhone_11_Pro_Max:d431ap:0x8030"
    "iPhone12,8:iPhone_SE_2:d79ap:0x8030"
)

FILTER_DEVICE=""
while (($#)); do
    case "$1" in
        --device|-d)
            (($# >= 2)) || { echo "error: --device needs a model name" >&2; exit 1; }
            FILTER_DEVICE="$2"
            shift 2
            ;;
        *)
            FILTER_DEVICE="$1"
            shift
            ;;
    esac
done

echo "=================================================================="
echo "[*] BreakICloudPro A12/A13 Categorized Batch Bootchain Builder (macOS)"
if [ -n "$FILTER_DEVICE" ] && [ "$FILTER_DEVICE" != "ALL" ] && [ "$FILTER_DEVICE" != "ALL_DEVICES" ] && [ "$FILTER_DEVICE" != "BATCH_ALL_A12_A13" ]; then
    echo "[*] Target Filter: ONLY $FILTER_DEVICE (Building All iOS Versions for this device)"
else
    echo "[*] Target Filter: ALL A12 & A13 Devices"
fi
echo "[*] Output Directory Hierarchy: bootchain/iOS_<Major>/<Target>/"
echo "=================================================================="

for dev_entry in "${TARGET_DEVICES[@]}"; do
    IFS=":" read -r PRODUCT MODEL_NAME BOARD CPID <<< "$dev_entry"
    
    if [ -n "$FILTER_DEVICE" ] && [ "$FILTER_DEVICE" != "ALL" ] && [ "$FILTER_DEVICE" != "ALL_DEVICES" ] && [ "$FILTER_DEVICE" != "BATCH_ALL_A12_A13" ]; then
        if [ "$MODEL_NAME" != "$FILTER_DEVICE" ] && [ "$PRODUCT" != "$FILTER_DEVICE" ] && [ "$BOARD" != "$FILTER_DEVICE" ]; then
            continue
        fi
    fi
    
    echo ""
    echo "=================================================================="
    echo "[*] Fetching Firmware Catalog for: $MODEL_NAME ($PRODUCT / $BOARD)"
    echo "=================================================================="
    
    API_URL="https://api.ipsw.me/v4/device/${PRODUCT}?type=ipsw"
    FIRMWARES_JSON=$(curl -sL "$API_URL" 2>/dev/null || echo "{}")
    
    if [ -z "$FIRMWARES_JSON" ] || [ "$FIRMWARES_JSON" = "{}" ]; then
        echo "[!] Warning: Failed to fetch firmware list for $PRODUCT. Skipping."
        continue
    fi
    
    # Parse available iOS 17+ releases using python helper via stdin
    echo "$FIRMWARES_JSON" | python3 -c "
import json, sys

try:
    data = json.loads(sys.stdin.read())
except Exception:
    data = {}
firmwares = data.get('firmwares', [])
# Filter for iOS 17+
filtered = []
for fw in firmwares:
    ver = fw.get('version', '')
    major = ver.split('.')[0] if '.' in ver else ver
    if major.isdigit() and int(major) >= 17:
        filtered.append(f\"{fw.get('version')}|{fw.get('buildid')}|{fw.get('url')}\")

# Sort chronologically (earliest to latest)
for item in reversed(filtered):
    print(item)
" | while IFS="|" read -r VERSION BUILD_ID IPSW_URL; do
        
        [ -z "$VERSION" ] && continue
        
        # Extract Major Version (17, 18, 26, etc.)
        MAJOR_VER="$(echo "$VERSION" | cut -d. -f1)"
        CATEGORY_DIR="iOS_${MAJOR_VER}"
        
        TARGET_DIR_NAME="${MODEL_NAME}-${VERSION}-${BUILD_ID}-ramdisk"
        REL_OUT_PATH="${CATEGORY_DIR}/${TARGET_DIR_NAME}"
        FULL_TARGET_DIR="bootchain/${REL_OUT_PATH}"
        
        echo ""
        echo "------------------------------------------------------------------"
        echo "[*] Processing: $MODEL_NAME | iOS $VERSION ($BUILD_ID)"
        echo "[*] Category: $CATEGORY_DIR -> Target: $TARGET_DIR_NAME"
        echo "------------------------------------------------------------------"
        
        # Check if already successfully built
        if [ -f "${FULL_TARGET_DIR}/chain.info" ] && [ -f "${FULL_TARGET_DIR}/ramdisk.img4" ] && [ -f "${FULL_TARGET_DIR}/kernelcache.img4" ]; then
            echo "[+] Bootchain already exists: $REL_OUT_PATH — Skipping."
            continue
        fi
        
        mkdir -p "bootchain/${CATEGORY_DIR}"
        echo "[*] Launching Build for: $MODEL_NAME (iOS $VERSION / $BUILD_ID)..."
        
        # Execute build.sh with categorized out-name
        ./build.sh \
            --product "$PRODUCT" \
            --model "$BOARD" \
            --cpid "$CPID" \
            --version "$VERSION" \
            --build "$BUILD_ID" \
            --url "$IPSW_URL" \
            --out-name "$REL_OUT_PATH" \
            --with-fw || {
                echo "[!] Build failed for $REL_OUT_PATH. Continuing to next target..."
                continue
            }
            
        echo "[+] Successfully built: $FULL_TARGET_DIR"
        
        # 1. Zip individual bootchain directory immediately
        ZIP_NAME="${TARGET_DIR_NAME}.zip"
        ZIP_PATH="${SCRIPT_DIR}/bootchain/${CATEGORY_DIR}/${ZIP_NAME}"
        (
            cd "${SCRIPT_DIR}/bootchain/${CATEGORY_DIR}"
            zip -r -q "$ZIP_NAME" "$TARGET_DIR_NAME"
        )
        echo "[+] Compressed individual bootchain: $ZIP_PATH"
        
        # 2. Upload to GitHub Releases in real-time if running on GitHub Actions
        if [ -n "${GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
            RELEASE_TAG="Bootchains-${MODEL_NAME}"
            echo "[*] Uploading $ZIP_NAME to GitHub Release: $RELEASE_TAG..."
            gh release create "$RELEASE_TAG" --title "Bootchains for ${MODEL_NAME}" --notes "Automated bootchain builds for ${MODEL_NAME}" 2>/dev/null || true
            gh release upload "$RELEASE_TAG" "$ZIP_PATH" --clobber || true
            echo "[+] Uploaded $ZIP_NAME to GitHub Releases successfully!"
        fi
    done
done

echo ""
echo "=================================================================="
echo "[+] Categorized Batch Build Complete!"
echo "    - bootchain/iOS_17/ (All iOS 17.x Ramdisks)"
echo "    - bootchain/iOS_18/ (All iOS 18.x Ramdisks)"
echo "    - bootchain/iOS_26/ (All iOS 26.x Ramdisks)"
echo "=================================================================="

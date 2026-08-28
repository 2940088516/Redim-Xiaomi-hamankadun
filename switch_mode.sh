#!/system/bin/sh
# ============================================================
# REDMI K90 音质优化 — 调音模式切换脚本（稳定版）
# 用法: sh switch_mode.sh [harman|berlin]
# ============================================================

MODE="$1"
LOG="/data/local/tmp/k90pm_audio.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [switch_mode] $1" >> "$LOG"; }

# 动态检测模块目录（兼容 Magisk / KSU / APatch）
MODDIR=""
for _p in "/data/adb/modules/k90pm_audio_plus" \
          "/data/adb/ksu/modules/k90pm_audio_plus" \
          "/data/adb/ap/modules/k90pm_audio_plus"; do
  [ -d "$_p" ] && MODDIR="$_p" && break
done
if [ -z "$MODDIR" ]; then
  echo "ERROR:moddir_not_found"
  log "模块目录未找到"
  exit 1
fi
log "模块目录: $MODDIR"

MODE_FILE="/data/local/tmp/k90_tuning_mode"

if [ "$MODE" = "harman" ]; then
    IDX=0
    SRC="$MODDIR/Link/odm/etc/dolby/dax-default.xml"
    SRC_VENDOR="$MODDIR/vendor/etc/dolby/dax-default.xml"
elif [ "$MODE" = "berlin" ]; then
    IDX=1
    SRC="$MODDIR/Link/odm/etc/dolby/dax-mode-1.xml"
    SRC_VENDOR="$MODDIR/vendor/etc/dolby/dax-mode-1.xml"
else
    echo "ERROR:unknown_mode"
    log "未知模式: $MODE"
    exit 1
fi

# 检查源文件是否存在
if [ ! -f "$SRC" ]; then
    echo "ERROR:src_not_found ($SRC)"
    log "源文件不存在: $SRC"
    exit 1
fi

DAX_SYS="/odm/etc/dolby/dax-default.xml"
DAX_VENDOR_SYS="/vendor/etc/dolby/dax-default.xml"

# 挂载 odm 路径
umount "$DAX_SYS" 2>/dev/null
if mount --bind "$SRC" "$DAX_SYS" 2>/dev/null; then
    restorecon "$DAX_SYS" 2>/dev/null
    log "ODM 挂载成功: $SRC → $DAX_SYS"
else
    echo "ERROR:mount_odm_failed"
    log "ODM 挂载失败"
    exit 1
fi

# 挂载 vendor 路径（如果存在对应源文件）
if [ -f "$SRC_VENDOR" ] && [ -f "$DAX_VENDOR_SYS" ]; then
    umount "$DAX_VENDOR_SYS" 2>/dev/null
    if mount --bind "$SRC_VENDOR" "$DAX_VENDOR_SYS" 2>/dev/null; then
        restorecon "$DAX_VENDOR_SYS" 2>/dev/null
        log "Vendor 挂载成功: $SRC_VENDOR → $DAX_VENDOR_SYS"
    else
        log "Vendor 挂载失败，但不影响 ODM 挂载"
    fi
fi

# 重启 audioserver
setprop sys.audio.dolby.reload 1 2>/dev/null
setprop ctl.restart audioserver 2>/dev/null
log "audioserver 重启中..."

# 等待重启（最多 15 次，每次 0.3 秒）
retry=0
while [ -z "$(pidof audioserver)" ] && [ $retry -lt 15 ]; do
    sleep 0.3
    retry=$((retry+1))
done

NEW_PID=$(pidof audioserver)
if [ -n "$NEW_PID" ]; then
    echo "$IDX" > "$MODE_FILE" 2>/dev/null
    echo "OK:$MODE:$NEW_PID"
    log "切换成功: $MODE (PID $NEW_PID)"
else
    echo "WARN:$MODE:no_pid"
    log "切换警告: audioserver 未重新启动"
fi
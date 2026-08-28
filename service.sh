#!/system/bin/sh
# ============================================================
# REDMI K90 Pro Max 音质优化 Ultra v2.0 — service.sh
# iOS 精确立方音量曲线 + 全场景优化
# ============================================================

MODDIR=${MODDIR:-$(dirname "$0")}
LOG="/data/local/tmp/k90pm_audio.log"
WORK="$MODDIR/work/volume"
AWK_SCRIPT="$MODDIR/system/etc/ios_curves.awk"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }
log "========== service 启动 =========="

chmod 755 "$MODDIR/post-fs-data.sh" 2>/dev/null

# ── Root 环境 ──
ROOT_TYPE="unknown"
[ -d "/proc/sukisu" ] && ROOT_TYPE="sukisu"
[ "$ROOT_TYPE" = "unknown" ] && { [ -f "/data/adb/ksud" ] || [ -x "/data/adb/ksu/bin/ksud" ]; } && ROOT_TYPE="kernelsu"
[ "$ROOT_TYPE" = "unknown" ] && [ -d "/data/adb/magisk" ] && ROOT_TYPE="magisk"

RESETPROP=""
for rp in "/data/adb/magisk/resetprop" "/data/adb/ksu/bin/resetprop" "/data/adb/ap/bin/resetprop"; do
  [ -x "$rp" ] && { RESETPROP="$rp"; break; }
done
[ -z "$RESETPROP" ] && command -v resetprop >/dev/null 2>&1 && RESETPROP="resetprop"
log "Root: $ROOT_TYPE / resetprop: ${RESETPROP:-不可用}"

# ── 等待系统启动 ──
count=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $count -lt 120 ]; do
  sleep 1; count=$((count + 1))
done
sleep 5
log "系统启动完成 (${count}s)"

set_prop() {
  local key="$1" value="$2"
  if [ -n "$RESETPROP" ]; then
    "$RESETPROP" "$key" "$value" 2>/dev/null
  else
    setprop "$key" "$value" 2>/dev/null
  fi
  log "  $key = $value"
}

# ── 第一部分：系统属性 ──
log "---------- 系统属性 ----------"
for s in media alarm system vc_call ring notification tts fm; do
  set_prop ro.config.${s}_vol_steps 16
done
set_prop ro.config.media_vol_default 10
set_prop ro.config.safe_media_volume_state 1
set_prop ro.config.safe_media_volume 0
set_prop ro.config.enable_audio_effects 1
set_prop persist.vendor.audio.effect_global 1
set_prop ro.vendor.dolby.dap_bypassed_on_tiny_volume false
# 蓝牙音量属性
set_prop persist.bluetooth.absvolume 1
set_prop persist.bluetooth.disable.absvol 0
set_prop ro.bluetooth.absvolume 1
set_prop persist.vendor.audio.a2dp.absolute.volume 1
set_prop persist.vendor.audio.a2dp.volume.sync 1
set_prop persist.vendor.audio.bt.volume.sync 1
set_prop persist.vendor.bt.a2dp.volume.sync 1

set_prop persist.audio.effect.device_map "speaker:dolby,headset:dolby,a2dp:dolby,usb:dolby,earpiece:dolby"
set_prop persist.vendor.audio.normalization 0
#set_prop persist.vendor.audio.normalization.target_lufs -16.0
#set_prop persist.vendor.audio.normalization.max_gain 6.0
set_prop persist.vendor.audio.drc.enabled 0
set_prop persist.vendor.audio.drc.ratio 3.0
set_prop persist.vendor.audio.drc.threshold -20
set_prop ro.config.enable_loudness_normalizer 0
set_prop persist.vendor.audio.speaker.protect.enable 0
set_prop persist.vendor.audio.speaker.safe.volume 0
set_prop persist.vendor.audio.speaker.max.level 100
set_prop ro.vendor.audio.speaker.protect false
set_prop vendor.audio.speaker.protect.enable 0
set_prop persist.vendor.audio.volume.limit 100
set_prop ro.config.volume_steps_speaker_safe 16
set_prop persist.vendor.audio.speaker.boost.enable 1
set_prop persist.vendor.audio.speaker.boost.gain 3
set_prop persist.vendor.audio.thermal.limit.disable 1
set_prop vendor.audio.thermal.mitigation false
set_prop persist.vendor.audio.thermal.mitigation false
set_prop persist.vendor.audio.volume.keys.control_active 1
set_prop ro.config.volume_keys_follow_active 1
set_prop persist.vendor.audio.volume.key.tone_disable 1
set_prop persist.vendor.audio.limiter.enable 0
set_prop persist.vendor.audio.limiter.threshold -5
set_prop persist.vendor.audio.comp2.enable 0
set_prop persist.vendor.audio.limiter.release 100
log "系统属性完成"

# ── 第二部分：音量曲线 bind mount ──
log "---------- 音量曲线 ----------"
mkdir -p "$WORK"

force_bind() {
  local src="$1" dst="$2" label="$3"
  if [ -f "$src" ] && [ -f "$dst" ]; then
    umount "$dst" 2>/dev/null
    mount --bind "$src" "$dst" 2>/dev/null
    grep -q "\-7225" "$dst" 2>/dev/null && log "  ✓ bind: $label" || log "  ✗ bind 失败: $label"
  else
    log "  ! 跳过: $label"
  fi
}

# ODM：awk处理，成功才挂，失败跳过（不走sed回退）
if [ -f "$AWK_SCRIPT" ]; then
  for odm_src in \
    "/odm/etc/audio_policy_engine_stream_volumes_mi.xml" \
    "/odm/etc/audio_policy_engine_default_stream_volumes_mi.xml"; do
    if [ -f "$odm_src" ]; then
      odm_tmp="$WORK/$(basename $odm_src)"
      awk -f "$AWK_SCRIPT" "$odm_src" > "$odm_tmp" 2>/dev/null
      if [ -s "$odm_tmp" ] && grep -q "\-7225" "$odm_tmp" 2>/dev/null; then
        force_bind "$odm_tmp" "$odm_src" "ODM $(basename $odm_src)"
      else
        rm -f "$odm_tmp"
        log "  ! ODM awk无效，跳过 $(basename $odm_src)"
      fi
    fi
  done
fi

# Vendor：直接force_bind静态iOS文件，保证响度正确
force_bind "$MODDIR/vendor/etc/audio_policy_engine_stream_volumes.xml" \
           "/vendor/etc/audio_policy_engine_stream_volumes.xml" "Vendor stream"
force_bind "$MODDIR/vendor/etc/audio_policy_engine_default_stream_volumes.xml" \
           "/vendor/etc/audio_policy_engine_default_stream_volumes.xml" "Vendor default"
force_bind "$MODDIR/vendor/etc/audio_policy_volumes.xml" \
           "/vendor/etc/audio_policy_volumes.xml" "Vendor policy"
force_bind "$MODDIR/system/vendor/etc/default_volume_tables.xml" \
           "/vendor/etc/default_volume_tables.xml" "Vendor tables"
log "音量曲线完成"

# ── 第三部分：引擎配置验证 ──
log "---------- 引擎验证 ----------"
for cfg in "/odm/etc/audio_policy_engine_configuration_mi.xml" \
           "/vendor/etc/audio_policy_engine_configuration.xml"; do
  [ -f "$cfg" ] || continue
  if grep -q '<point>' "$cfg" 2>/dev/null && ! grep -q "\-7225" "$cfg" 2>/dev/null; then
    wk="$WORK/engine_$(basename $cfg)"
    [ -f "$AWK_SCRIPT" ] && awk -f "$AWK_SCRIPT" "$cfg" > "$wk" 2>/dev/null
    if [ -f "$wk" ] && grep -q "\-7225" "$wk" 2>/dev/null; then
      umount "$cfg" 2>/dev/null
      mount --bind "$wk" "$cfg" 2>/dev/null
      log "  ✓ 引擎修复: $(basename $cfg)"
    fi
  fi
done

# ── 第四部分：Dolby DVL 全局化（写死成品，自动挂载 + 验证）──
# 2026-08-06 方案：config 已在打包时写死（杜比全局化 + v4a）放进 Link/ 与 vendor/，
#  由 post-fs-data 的 bind_tree 自动挂载到系统。此处仅验证，不做运行时动态修改。
log "---------- Dolby DVL ----------"
AIDL=""
for sku_dir in /vendor/etc/audio/sku_canoe /vendor/etc/audio/sku_myron /vendor/etc/audio/sku_* /vendor/etc/audio; do
  candidate="$sku_dir/audio_effects_config.xml"
  if [ -f "$candidate" ]; then
    AIDL="$candidate"
    log "  检测到 AIDL: $AIDL"
    break
  fi
done
# 验证系统上生效的 postprocess 是否已含杜比全局化(dlb_ring_listener)
if [ -n "$AIDL" ] && sed -n '/<postprocess>/,/<\/postprocess>/p' "$AIDL" 2>/dev/null | grep -q 'dlb_ring_listener'; then
  log "Dolby DVL ✓ (写死成品已自动挂载生效)"
elif [ -f "$MODDIR/Link/odm/etc/audio_effects_config.xml" ]; then
  # 兜底：若系统目标未被 post-fs-data 挂载到，用模块 Link 成品 bind
  umount "$AIDL" 2>/dev/null
  mount --bind "$MODDIR/Link/odm/etc/audio_effects_config.xml" "$AIDL" 2>/dev/null
  log "Dolby DVL 兜底 bind（Link 成品）"
else
  log "Dolby DVL ✗：未找到写死成品"
fi

# ── 第五部分：长按无级调节 ──
log "---------- 无级调节 ----------"
if command -v settings >/dev/null 2>&1; then
  settings put system key_repeat_delay 200 2>/dev/null
  settings put system key_repeat_interval 35 2>/dev/null
  settings put system volume_keys_control_stream 0 2>/dev/null
  settings put system volume_keys_vibrate 0 2>/dev/null
fi
command -v cmd >/dev/null 2>&1 && cmd input set-key-repeat --delay 200 --interval 35 2>/dev/null
log "key_repeat: 200ms/35ms"

# ── 第六部分：低功耗清除 ──
log "---------- 低功耗 ----------"
if command -v settings >/dev/null 2>&1; then
  for k in audio_low_power_mode miui_audio_power_save hyper_audio_power_save; do
    settings put global "$k" 0 2>/dev/null
    settings put system "$k" 0 2>/dev/null
  done
fi
set_prop ro.config.low_volume false
set_prop persist.vendor.audio.low_power false
set_prop persist.vendor.audio_hal.low_power false
set_prop persist.vendor.audio.power.save.enable 0
set_prop persist.vendor.audio.power.save.setting 0
set_prop persist.vendor.audio.silencelowpower.support false
set_prop persist.sys.miuix.volume.power_save 0
set_prop persist.sys.miui.audio.power_save 0
set_prop persist.sys.hyper.audio.power_save 0

LP_LIST="/odm/etc/audio/audio_lowpower_app_list.xml"
if [ -f "$LP_LIST" ]; then
  LP_WORK="$MODDIR/work/lp"
  mkdir -p "$LP_WORK"
  echo '<?xml version="1.0" encoding="UTF-8"?><audio_lowpower_app_list></audio_lowpower_app_list>' \
    > "$LP_WORK/audio_lowpower_app_list.xml"
  umount "$LP_LIST" 2>/dev/null
  mount --bind "$LP_WORK/audio_lowpower_app_list.xml" "$LP_LIST" 2>/dev/null
  log "低功耗白名单已清空"
fi

# ── 第七部分：跨应用音量补偿 ──
log "---------- 音量补偿 ----------"
command -v settings >/dev/null 2>&1 && settings put global audio_volume_normalization 0 2>/dev/null
rm -f /data/system/audio/per_app_volume_*.xml 2>/dev/null
set_prop persist.vendor.audio.ducking.enabled 0

# ── 第八部分：DAX3 参数 ──
log "---------- DAX3 ----------"
DAX3_SNAP="/data/local/tmp/k90pm_dax3_snapshot.json"
if [ -f "$DAX3_SNAP" ]; then
  log "检测到 DAX3 快照，从 APP 设定恢复"
  while IFS= read -r line; do
    key=$(echo "$line" | sed -n 's/.*"\([^"]*\)"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    val=$(echo "$line" | sed -n 's/.*"\([^"]*\)"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\2/p')
    [ -n "$key" ] && [ -n "$val" ] && set_prop "$key" "$val"
  done < "$DAX3_SNAP"
else
  set_prop persist.vendor.dolby.global.enable 1
  set_prop persist.vendor.dolby.dialog.enhancer.enable 1
  set_prop persist.vendor.dolby.dialog.enhancer.amount 7
  set_prop persist.vendor.dolby.volume.leveler.enable 0
  set_prop persist.vendor.dolby.volume.leveler.amount 0
  set_prop persist.vendor.dolby.virtualizer.enable 1
  set_prop persist.vendor.dolby.virtualizer.amount 6
  set_prop persist.vendor.dolby.bass.enable 1
  set_prop persist.vendor.dolby.bass.boost 0
  set_prop persist.vendor.dolby.spectral.enable 1
  set_prop persist.vendor.dolby.spectral.boost 7
  set_prop persist.vendor.dolby.ieq.enable 0
  set_prop vendor.dolby.dap.pcequal 0
  set_prop vendor.dolby.dap.pctype 0
fi
log "DAX3 完成"

# ── 第九部分：音量渐变 ──
set_prop persist.vendor.audio.volume.fade_ms 60
set_prop persist.vendor.audio.volume.ramp.time.ms 60
set_prop ro.audio.volume_ramp_time_ms 60
log "音量渐变: 60ms"

# ── 第十部分：音频服务检查 ──
log "---------- 音频服务 ----------"
log "HAL: $(pidof audiohalservice.qti 2>/dev/null || echo 无)"
log "AP: $(pidof audioserver 2>/dev/null || echo 无)"



# ── 第十一部分：per-device 音量记忆 ──
log "---------- per-device ----------"
nice -n 19 sh "$MODDIR/system/etc/per_device_volume.sh" > /dev/null 2>&1 &
log "per-device 启动"

# ── 第十二部分：高音量降档守护 ──
log "---------- 降档守护 ----------"
[ -x "$MODDIR/bass_watchdog.sh" ] || chmod 755 "$MODDIR/bass_watchdog.sh"
sh "$MODDIR/bass_watchdog.sh" > /dev/null 2>&1 &
log "降档守护已启动（PID $!）"

# ── 最终验证 ──
log "---------- 最终验证 ----------"
log "steps: media=$(getprop ro.config.media_vol_steps) alarm=$(getprop ro.config.alarm_vol_steps)"
for f in \
  "/odm/etc/audio_policy_engine_stream_volumes_mi.xml:ODM stream" \
  "/odm/etc/audio_policy_engine_default_stream_volumes_mi.xml:ODM default" \
  "/vendor/etc/audio_policy_engine_stream_volumes.xml:Vendor stream" \
  "/vendor/etc/audio_policy_engine_default_stream_volumes.xml:Vendor default" \
  "/vendor/etc/audio_policy_volumes.xml:Vendor policy" \
  "/vendor/etc/default_volume_tables.xml:Vendor tables"; do
  path="${f%%:*}"; label="${f##*:}"
  grep -q "\-7225" "$path" 2>/dev/null && log "$label: ✓" || log "$label: ✗"
done
log "dax3_dialog: $(getprop persist.vendor.dolby.dialog.enhancer.enable)"
log "speaker_protect: $(getprop persist.vendor.audio.speaker.protect.enable)"
log "limiter: $(getprop persist.vendor.audio.limiter.enable)"

# ════════════════════════════════════════════════════════════════
# V4A (ViPER4Android RE / AIDL) — 只挂载 so 效果库
# 2026-08-06 方案：audio_effects_config.xml 已在打包时【写死成品】放进
#  Link/ 与 vendor/ 目录，由 post-fs-data.sh 的 bind_tree 自动挂载到系统，
#  service.sh 不再动态改/不再重复挂 config。
#  此处仅挂载唯一需要的、post-fs-data 不覆盖的：V4A 效果库 so。
#  不重启音频服务（避免 Dolby/MiSound 掉线导致响度下降）。
# ════════════════════════════════════════════════════════════════
V4A_LOG="/data/adb/viper_install.log"
vlog() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [service] $1" >> "$V4A_LOG"; }
[ -f "$V4A_LOG" ] || : > "$V4A_LOG"
vlog "---> V4A so 库挂载 start <---"

EFFECT_LIB="libv4a_aidl.so"

# 解析 V4A so 的真实源根目录（兼容 Magisk 的 system/vendor 与 KSU 下被软链化/嵌套的落点）
# 优先级：顶层 vendor(KSU 软链目标) > system/vendor(Magisk 真目录) > 全模块 find 兜底
resolve_vendor_root() {
  local cand
  # 1) 顶层 vendor（KSU 把 system/vendor 软链到 ../vendor，so 物理在顶层 vendor 时优先）
  cand="$MODDIR/vendor"
  if [ -f "$cand/lib64/soundfx/$EFFECT_LIB" ] || [ -f "$cand/lib/soundfx/$EFFECT_LIB" ]; then
    echo "$cand"; return
  fi
  # 2) system/vendor（Magisk 真目录）
  cand="$MODDIR/system/vendor"
  if [ -f "$cand/lib64/soundfx/$EFFECT_LIB" ] || [ -f "$cand/lib/soundfx/$EFFECT_LIB" ]; then
    echo "$cand"; return
  fi
  # 3) 兜底：全模块搜索真实 so 落点（KSU 下偶发 vendor/vendor 两层嵌套）
  local found
  found=$(find "$MODDIR" -path "*soundfx/$EFFECT_LIB" -type f 2>/dev/null | head -n 1)
  if [ -n "$found" ]; then
    # found 形如 .../X/lib64/soundfx/libv4a_aidl.so，向上 3 层得 .../X（含 lib/lib64 的 vendor 根）
    echo "$(dirname "$(dirname "$(dirname "$found")")")"
  else
    echo "$MODDIR/system/vendor"
  fi
}
MOD_VENDOR="$(resolve_vendor_root)"
log "V4A vendor 源根解析 -> $MOD_VENDOR (是否存在 so: $([ -f "$MOD_VENDOR/lib64/soundfx/$EFFECT_LIB" ] && echo yes || echo no))"
vlog "resolve_vendor_root -> $MOD_VENDOR"

# 全局命名空间挂载（照官方：先 nsenter 进 init ns，失败才回退本地 bind）
ns_bind() {
  if nsenter -t 1 -m -- mount -o bind "$1" "$2" 2>/dev/null; then
    return 0
  fi
  umount "$2" 2>/dev/null
  mount -o bind "$1" "$2" 2>/dev/null
  return $?
}

# bind 到一个目录（放入目标 so 后整体 bind），增强日志：每个失败点都写日志、不吞错
bind_vendor_sfx() {
  local SYS_TARGET="$1" MOD_SRC="$2"
  local RC=0
  if [ ! -d "$SYS_TARGET" ]; then log "V4A sfx skip $SYS_TARGET (dir not found)"; vlog "skip $SYS_TARGET (dir not found)"; return; fi
  if [ ! -f "$MOD_SRC/$EFFECT_LIB" ]; then log "V4A sfx skip $SYS_TARGET (src lib NOT found in $MOD_SRC, check path)"; vlog "skip $SYS_TARGET (no src lib)"; return; fi
  # 目标已存在该库则跳过（系统原厂/overlay 已挂），但记录来源域以便诊断
  if [ -f "$SYS_TARGET/$EFFECT_LIB" ]; then
    log "V4A sfx skip $SYS_TARGET (lib already present: $(ls -lZ "$SYS_TARGET/$EFFECT_LIB" 2>/dev/null | awk '{print $1,$4}'))"
    vlog "skip $SYS_TARGET (lib already present)"; return
  fi
  local WORK="$MODDIR/work_mount_sfx$(echo "$SYS_TARGET" | tr '/' '_')"
  rm -rf "$WORK"; mkdir -p "$WORK"
  cp -af "$SYS_TARGET"/. "$WORK/" 2>/dev/null
  CP_ERR=$(cp -af "$MOD_SRC/$EFFECT_LIB" "$WORK/$EFFECT_LIB" 2>&1)
  if [ $? -ne 0 ]; then log "V4A sfx cp FAILED: $CP_ERR"; vlog "cp failed: $CP_ERR"; return; fi
  chmod 644 "$WORK/$EFFECT_LIB" 2>/dev/null
  # 给 work 目录整体打 vendor_file 域（so 必须在 vendor_file 域才能被 audio HAL dlopen）
  CHCON_ERR=$(chcon -R u:object_r:vendor_file:s0 "$WORK" 2>&1)
  if [ $? -ne 0 ]; then
    # 兼容 -t 语法
    CHCON_ERR=$(chcon -R -t vendor_file "$WORK" 2>&1)
    log "V4A sfx chcon1 failed, retry: $CHCON_ERR"
  fi
  # 挂载（进 init ns）
  ns_bind "$WORK" "$SYS_TARGET"; RC=$?
  # 挂载后立即验证：从 init ns 看目标 so 是否真的可见
  local VISIBLE=no
  if [ -f "$SYS_TARGET/$EFFECT_LIB" ]; then VISIBLE=yes; fi
  log "V4A sfx bind $WORK -> $SYS_TARGET (rc=$RC, visible=$VISIBLE, selabel=$(ls -lZ "$SYS_TARGET/$EFFECT_LIB" 2>/dev/null | awk '{print $4}'))"
  vlog "V4A sfx bind $SYS_TARGET rc=$RC visible=$VISIBLE"
  # 若"看起来可见"但域是 vendor_file，再显式对目标打一次域（兜底 overlay 场景）
  if [ "$VISIBLE" = yes ]; then
    chcon u:object_r:vendor_file:s0 "$SYS_TARGET/$EFFECT_LIB" 2>/dev/null || true
  fi
}

# 挂载 V4A so 库到 lib/lib64 soundfx（config 已由 post-fs-data 自动挂载，无需处理）
for a in lib lib64; do bind_vendor_sfx "/vendor/$a/soundfx" "$MOD_VENDOR/$a/soundfx"; done

# 最终验证：列出每个目标 soundfx 目录下 V4A so 是否就位（含 init ns 视角）
log "---------- 最终 so 库验证 ----------"
for d in /vendor/lib/soundfx /vendor/lib64/soundfx /apex/*/lib64/soundfx /apex/*/lib/soundfx; do
  if [ -f "$d/$EFFECT_LIB" ]; then
    log "V4A FOUND: $d/$EFFECT_LIB ($(ls -lZ "$d/$EFFECT_LIB" 2>/dev/null | awk '{print $1,$4}'))"
  else
    log "V4A MISSING: $d/$EFFECT_LIB"
  fi
done

# 不重启音频服务：让系统在现有/下次初始化时自然加载（避免 Dolby/MiSound 掉线）
# 2026-08-06 v2.0 修正：必须重启音频服务，AudioFlinger 才会重新解析写死的 config、
#   重建下位效果链（Music Volume Listener + V4A 才会实例化）。
#   重启前：等待音频服务已启动就绪 + 再缓 5s，避免开机竞态。
vlog "V4A so 库挂载完成（config 已由 post-fs-data 写死挂载）"
vlog "---> V4A so 库挂载 done <---"

# ── 第十三部分：检测音频服务就绪后延迟重启音频服务（重建效果链）──
# 目的：AudioFlinger 开机时按旧 config 建立效果链（无 V4A/MusicVolume）。
#       此处等音频服务真正启动完成并稳定 5s 后，kill audioserver 触发重建，
#       让 AudioFlinger 重新解析【写死 config】→ Music Volume Listener + V4A 进链。
log "---------- 音频服务重建 ----------"
vlog "---> 等待音频服务就绪后重启 <---"

# 函数:检测音频服务/相关进程是否已在运行
audio_ready() {
  pidof audioserver >/dev/null 2>&1 || pidof audiohalservice >/dev/null 2>&1 || pidof audio.service-aidl.mediatek >/dev/null 2>&1
}

# 等待音频服务启动(最多 30s)
ai=0
while ! audio_ready && [ $ai -lt 30 ]; do
  sleep 1; ai=$((ai + 1))
done
log "音频服务就绪检测完成(${ai}s): $(pidof audioserver 2>/dev/null || echo none) audioserver"

# 等 5s 让音频服务完全稳定(避免刚启动/初始化中重启导致竞态)
sleep 5
log "延迟 5s 结束，准备重启音频服务"

# kill 音频相关进程，触发 AudioFlinger 用写死 config 重建效果链
for proc in audioserver audiohalservice audiohalservice.qti audio.service-aidl.mediatek secaudiohalaidl; do
  pids=$(pidof "$proc" 2>/dev/null)
  [ -n "$pids" ] && kill $pids 2>/dev/null && vlog "重启音频: $proc ($pids)"
done
sleep 3
log "音频服务已重启(重建效果链)。当前: $(pidof audioserver 2>/dev/null || echo 重启中)"
vlog "---> 音频服务重建 done <---"
log "root_type: $ROOT_TYPE"


# ── 第十五部分：开机 V4A 参数写回（拉起 APP 隐形服务，用 v5 SHM mmap 写回）──
# 背景：v2.x 之前用 cp 覆盖 SHM 快照实测无效（驱动通过 mmap 页缓存读取，cp 重写
#       不会刷新驱动已映射的视图）。本次改为：音频服务重建完成、驱动已 map SHM 后，
#       由模块(root)拉起 APP 的隐形一次性服务 ViperService（ACTION_START/无 action），
#       该服务复用 APP 调音页同一套 v5 SHM 写通道(ConfigChannel.writeFullState)把快照写回，
#       与驱动同一条页缓存映射 → 驱动能可靠感知，实现开机自动恢复。写回后服务自动 stopSelf。
log "---------- 开机 V4A 参数写回(APP 隐形服务) ----------"
# 先检测伴生 APP 是否安装；未安装则跳过（不做无意义的拉起）
if ! pm path com.k90pm.tuner >/dev/null 2>&1; then
  log "未安装伴生 APP(com.k90pm.tuner)，跳过 V4A 参数写回"
  log "root_type: done"
else
# 等 4s 让音频服务重建完成后的驱动稳定 map SHM（避免刚重建/初始化中竞态）
sleep 4
log "重启音频后稳定 4s，拉起 APP ViperService 写回参数"
# 用 root am 启动 APP 隐形服务（不弹 UI、无通知栏）；写完即自关。
# 若服务已在运行则重复 start 无副作用（一次性，幂等）。
am startservice -n com.k90pm.tuner/.v4a2.service.ViperService 2>&1 | grep -v 'Error' | head -1
log "ViperService 已拉起（写回后自动 stopSelf 退出）"
fi
log "root_type: done"
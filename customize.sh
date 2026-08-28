#!/system/bin/sh
# ============================================================
# 模块名称: Xiaomi Redmi Harman Kardon Ultra
# 版本: v1.6T
# 作者: 016 TQ-QUAN
# 描述: 音频调校模块安装脚本 - 显示真实机型
# ============================================================

SKIPUNZIP=0
[ ! "$MODPATH" ] && MODPATH=${0%/*}

# ============================================================
# 辅助函数：执行属性设置并显示命令
# ============================================================

set_prop() {
    local prop=$1
    local value=$2
    ui_print "    📝 setprop $prop $value"
    setprop "$prop" "$value" 2>/dev/null
}

# ============================================================
# 直接读取手机真实信息
# ============================================================

# 真实机型名称（如 "Xiaomi 17"）
MODEL_NAME=$(getprop ro.product.model 2>/dev/null)
[ -z "$MODEL_NAME" ] && MODEL_NAME=$(getprop ro.product.marketname 2>/dev/null)

# 真实设备代号（如 "xiaomi17"）
DEVICE_NAME=$(getprop ro.product.device 2>/dev/null)
[ -z "$DEVICE_NAME" ] && DEVICE_NAME=$(getprop ro.product.name 2>/dev/null)

# 厂商名称（如 "Xiaomi"）
MANUFACTURER=$(getprop ro.product.manufacturer 2>/dev/null)
[ -z "$MANUFACTURER" ] && MANUFACTURER=$(getprop ro.product.brand 2>/dev/null)

# 硬件型号/内部代号（如 "2410DPN6CC"）
HARDWARE_MODEL=$(getprop ro.product.vendor.model 2>/dev/null)
[ -z "$HARDWARE_MODEL" ] && HARDWARE_MODEL=$(getprop ro.product.board 2>/dev/null)

# Android 版本
ANDROID_VER=$(getprop ro.build.version.release 2>/dev/null)

# 设备代号备选
DEVICE2=$(getprop ro.product.vendor.device 2>/dev/null)
DEVICE3=$(getprop ro.build.product 2>/dev/null)

# ============================================================
# 安装开始
# ============================================================

ui_print "╔══════════════════════════════════════╗"
ui_print "║   小米红米哈曼卡顿音频调校模块  v1.6T   ║"
ui_print "║    TQ-QUAN  By016                    ║"
ui_print "╚══════════════════════════════════════╝"
sleep 1

# ============================================================
# 步骤 1：显示真实设备信息
# ============================================================

ui_print "▶ 步骤 1/6：采集设备信息"

ui_print "  ├─ 手机型号  : $MODEL_NAME"
ui_print "  ├─ 品牌厂商  : $MANUFACTURER"
ui_print "  ├─ 内部代号  : $HARDWARE_MODEL"
ui_print "  ├─ 设备代号  : $DEVICE_NAME"
ui_print "  ├─ 厂商代号  : $DEVICE2"
ui_print "  ├─ 构建代号  : $DEVICE3"
ui_print "  └─ Android 版: $ANDROID_VER"
ui_print " "
sleep 1

# ============================================================
# 步骤 2：检测 Dolby 配置文件
# ============================================================

ui_print "▶ 步骤 2/6：检测 Dolby 配置文件"

FILE_PATHS="/vendor/etc/dolby/dax-default.xml /system/vendor/etc/dolby/dax-default.xml /odm/etc/dolby/dax-default.xml"
file_exists=false

for path in $FILE_PATHS; do
    ui_print "  ├─ test -f $path"
    if [ -f "$path" ]; then
        ui_print "  │  ✅ 文件存在"
        file_exists=true
        break
    else
        ui_print "  │  ❌ 文件不存在"
    fi
done

if [ "$file_exists" = false ]; then
    ui_print "  ❌ 设备不兼容，缺少 Dolby 配置"
    ui_print " "
    ui_print "╔═════════════════════════════════════════════╗"
    ui_print "║  ❌ 安装失败：设备不兼容，缺少 Dolby 配置     ║"
    ui_print "╚═════════════════════════════════════════════╝"
    abort
fi

ui_print "  ✅ 兼容性检测通过"
ui_print " "
sleep 1

# ============================================================
# 步骤 3：清理残留文件
# ============================================================

ui_print "▶ 步骤 3/6：清理旧版本残留文件"

ui_print "  ├─ rm -rf /data/local/tmp/k90pm_audio_work"
rm -rf "/data/local/tmp/k90pm_audio_work" 2>/dev/null

ui_print "  ├─ rm -rf /data/local/tmp/k90pm_dolby_fix"
rm -rf "/data/local/tmp/k90pm_dolby_fix" 2>/dev/null

ui_print "  ├─ rm -rf /data/local/tmp/k90pm_lp_fix"
rm -rf "/data/local/tmp/k90pm_lp_fix" 2>/dev/null

ui_print "  ├─ rm -f  /data/local/tmp/k90pm_audio.log"
rm -f "/data/local/tmp/k90pm_audio.log" 2>/dev/null

ui_print "  ├─ rm -f  /data/local/tmp/k90pm_eq_current.json"
rm -f "/data/local/tmp/k90pm_eq_current.json" 2>/dev/null

ui_print "  ├─ rm -f  /data/local/tmp/k90pm_eq_presets.json"
rm -f "/data/local/tmp/k90pm_eq_presets.json" 2>/dev/null

ui_print "  └─ rm -f  /data/local/tmp/k90pm_wp_choice"
rm -f "/data/local/tmp/k90pm_wp_choice" 2>/dev/null

ui_print "  ✅ 清理完成"
ui_print " "
sleep 1

# ============================================================
# 步骤 4：卸载旧模块
# ============================================================

ui_print "▶ 步骤 4/6：检测并卸载旧版本模块"

OLD_VER=""
for mod_path in "/data/adb/modules/k90pm_audio_plus" \
                "/data/adb/ksu/modules/k90pm_audio_plus" \
                "/data/adb/ap/modules/k90pm_audio_plus"; do
    ui_print "  ├─ test -f $mod_path/module.prop"
    if [ -f "$mod_path/module.prop" ]; then
        OLD_VER=$(grep '^version=' "$mod_path/module.prop" | cut -d= -f2)
        ui_print "  │  ⚠️ 发现旧版本: v$OLD_VER"
        break
    fi
done

if [ -n "$OLD_VER" ]; then
    ui_print "  ├─ rm -rf /data/adb/modules/k90pm_audio_plus"
    rm -rf "/data/adb/modules/k90pm_audio_plus" 2>/dev/null
    ui_print "  ├─ rm -rf /data/adb/ksu/modules/k90pm_audio_plus"
    rm -rf "/data/adb/ksu/modules/k90pm_audio_plus" 2>/dev/null
    ui_print "  └─ rm -rf /data/adb/ap/modules/k90pm_audio_plus"
    rm -rf "/data/adb/ap/modules/k90pm_audio_plus" 2>/dev/null
    ui_print "  ✅ 旧版本已卸载"
else
    ui_print "  ✅ 未检测到旧版本，执行全新安装"
fi
ui_print " "
sleep 1

# ============================================================
# 步骤 5：设置音频属性
# ============================================================

ui_print "▶ 步骤 5/6：设置音频系统属性"

ui_print "  ├─ 关闭音频压缩器..."
set_prop "vendor.audio.comp2.enable" "0"
sleep 0.3

ui_print "  ├─ 关闭音频限幅器..."
set_prop "vendor.audio.limiter.enable" "0"
sleep 0.3

ui_print "  ├─ 关闭响度归一化..."
set_prop "config.enable_loudness_normalizer" "0"
sleep 0.3

ui_print "  ├─ 设置音量步进数..."
set_prop "config.volume_steps_speaker_safe" "16"
sleep 0.3

ui_print "  ├─ 设置音量键控制活跃音频流..."
set_prop "vendor.audio.volume.keys.control_active" "1"
sleep 0.3

ui_print "  ├─ 禁用音量键提示音..."
set_prop "vendor.audio.volume.key.tone" "disable"
sleep 0.3

ui_print "  ├─ 开启扬声器增强..."
set_prop "persist.vendor.audio.speaker.boost.enable" "1"
sleep 0.3

ui_print "  ├─ 设置扬声器最大音量..."
set_prop "persist.vendor.audio.speaker.max.level" "100"
sleep 0.3

ui_print "  ├─ 关闭扬声器保护..."
set_prop "persist.vendor.audio.speaker.protect.enable" "0"
sleep 0.3

ui_print "  ├─ 关闭安全音量限制..."
set_prop "persist.vendor.audio.speaker.safe.volume" "0"
sleep 0.3

ui_print "  ├─ 禁用温度限制..."
set_prop "persist.vendor.audio.thermal.limit.disable" "1"
sleep 0.3

ui_print "  ├─ 禁用热量缓解..."
set_prop "persist.vendor.audio.thermal.mitigation" "false"
sleep 0.3

ui_print "  └─ 设置音频归一化目标..."
set_prop "persist.vendor.audio.normalization.target_luFs" "-16.0"
sleep 0.3

ui_print "  ✅ 音频属性设置完成"
ui_print " "
sleep 1

# ============================================================
# 保存系统版本信息
# ============================================================

ui_print "▶ 保存系统版本信息"
ui_print "  ├─ echo $(getprop ro.build.display.id) > $MODPATH/system_version"
echo "$(getprop ro.build.display.id)" > "$MODPATH/system_version"
ui_print "  └─ ✅ 版本信息已保存"
ui_print " "
sleep 1

# ============================================================
# 步骤 6：SELinux 权限设置
# ============================================================

ui_print "▶ 步骤 6/6：设置 SELinux 上下文"

set_permissions() {
    ui_print "  ├─ set_perm_recursive $MODPATH 0 0 0755 0644"
    set_perm_recursive $MODPATH 0 0 0755 0644

    [ -d "$MODPATH/vendor" ] && {
        ui_print "  ├─ set_perm_recursive $MODPATH/vendor 0 0 0755 0644 u:object_r:vendor_configs_file:s0"
        set_perm_recursive $MODPATH/vendor 0 0 0755 0644 u:object_r:vendor_configs_file:s0 2>/dev/null
    }

    [ -d "$MODPATH/Link" ] && {
        ui_print "  ├─ set_perm_recursive $MODPATH/Link 0 0 0755 0644"
        set_perm_recursive $MODPATH/Link 0 0 0755 0644 2>/dev/null
    }

    [ -d "$MODPATH/system/vendor/etc" ] && {
        ui_print "  ├─ set_perm_recursive $MODPATH/system/vendor/etc 0 0 0755 0644 u:object_r:vendor_configs_file:s0"
        set_perm_recursive $MODPATH/system/vendor/etc 0 0 0755 0644 u:object_r:vendor_configs_file:s0 2>/dev/null
    }

    [ -f "$MODPATH/post-fs-data.sh" ] && {
        ui_print "  ├─ chmod 755 $MODPATH/post-fs-data.sh"
        set_perm $MODPATH/post-fs-data.sh 0 0 0755 2>/dev/null
    }

    [ -f "$MODPATH/service.sh" ] && {
        ui_print "  ├─ chmod 755 $MODPATH/service.sh"
        set_perm $MODPATH/service.sh 0 0 0755 2>/dev/null
    }

    [ -f "$MODPATH/uninstall.sh" ] && {
        ui_print "  ├─ chmod 755 $MODPATH/uninstall.sh"
        set_perm $MODPATH/uninstall.sh 0 0 0755 2>/dev/null
    }

    [ -d "$MODPATH/vendor/lib/soundfx" ] && {
        ui_print "  ├─ chcon -R u:object_r:vendor_file:s0 $MODPATH/vendor/lib/soundfx"
        chcon -R u:object_r:vendor_file:s0 "$MODPATH/vendor/lib/soundfx" 2>/dev/null || true
    }

    [ -d "$MODPATH/vendor/lib64/soundfx" ] && {
        ui_print "  └─ chcon -R u:object_r:vendor_file:s0 $MODPATH/vendor/lib64/soundfx"
        chcon -R u:object_r:vendor_file:s0 "$MODPATH/vendor/lib64/soundfx" 2>/dev/null || true
    }
}

set_permissions
ui_print "  ✅ SELinux 权限设置完成"
ui_print " "
sleep 1

# ============================================================
# 完成
# ============================================================

ui_print "╔═════════════════════════════════════╗"
ui_print "║                                     ║"
ui_print "║           ✅ 安装完成               ║"
ui_print "║                                     ║"
ui_print "║     手机型号  : $MODEL_NAME          ║"
ui_print "║     设备代号  : $DEVICE_NAME         ║"
ui_print "║     Android   : $ANDROID_VER        ║"
ui_print "║                                     ║"
ui_print "║    昔留余憾，今始能为，然不及故人      ║"
ui_print "║                             --QUAN  ║"
ui_print "╚═════════════════════════════════════╝"
ui_print " "

m_t() { :; }
m_t
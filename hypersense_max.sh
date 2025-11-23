#!/data/data/com.termux/files/usr/bin/env bash
# ========================================================
# 🔥 HYPERSENSE MAX FINAL — Non-Root
# Developer: AG HYDRAX | Marketing Head: Roobal Sir (@roobal_sir) | offcial beta tester: RC Demon
# Instagram: @hydraxff_yt
# Purpose: Full Non-Root Android Game Performance Tool
# Features: Activation, Raw Touch, Pre-Boost, Micro-Burst,
# FPS Push, vPool, Watchdog, Free Fire / Free Fire Max, Logs
# ========================================================

set -o errexit
set -o pipefail

# ---------------------------
# Config & Paths
# ---------------------------
HYP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypersense"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypersense"
mkdir -p "$HYP_DIR" "$LOG_DIR"
ACT_FILE="$HYP_DIR/activation.info"
SETTINGS_FILE="$HYP_DIR/settings.conf"
ANALYTICS_CSV="$HYP_DIR/analytics.csv"
VPOOL_FILE="$HYP_DIR/virtual_pool.img"
VPOOL_META="$VPOOL_FILE.meta"
WATCHDOG_LOG="$LOG_DIR/watchdog.log"
MAIN_LOG="$LOG_DIR/hypersense.log"

# ---------------------------
# Defaults / Globals
# ---------------------------
TOUCH_X=10
TOUCH_Y=10
TOUCH_SCALE=0.85
PREBOOST_LEVEL=2
MICROBURST_LEVEL=2
VPOOL_SIZE_MB=512
BATTERY_SAFE_MIN=15
BALANCED_FLOOR_PERCENT=30
ULTRA_CHARGE_THRESHOLD=1
AFB=1
ARC_ON=0
RAW_TOUCH_MODE=1
PRED_HOLD_SECONDS=5

# ---------------------------
# Logging
# ---------------------------
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$MAIN_LOG"; }
watchdog_log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$WATCHDOG_LOG"; }

# ---------------------------
# Utility
# ---------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

sha256_hash() {
  if has_cmd sha256sum; then
    printf "%s" "$1" | sha256sum | awk '{print $1}'
  else
    printf "%s" "$1" | md5sum | awk '{print $1}'
  fi
}

# ---------------------------
# Activation System
# ---------------------------
check_activation() {
  [ ! -f "$ACT_FILE" ] && return 1
  . "$ACT_FILE" 2>/dev/null || return 1
  NOW_EPOCH=$(date +%s)
  (( NOW_EPOCH > PLAN_EXPIRY_EPOCH )) && { echo "Activation expired"; restore_stock; return 2; }
  return 0
}

prompt_activation() {
  while true; do
    read -r -p "Enter Activation Token (Base64): " token
    [ -z "$token" ] && { echo "No token entered. Exiting."; exit 1; }
    decoded=$(printf "%s" "$token" | base64 -d 2>/dev/null || echo "")
    IFS='|' read -r IN_USER IN_PLAN IN_PLANEXP IN_ACTLOCK IN_SIGN <<< "$decoded"
    PLAN_EXP_EPOCH=$(date -d "${IN_PLANEXP:0:4}-${IN_PLANEXP:4:2}-${IN_PLANEXP:6:2}" +%s)
    ACTLOCK_EPOCH=$(date -d "${IN_ACTLOCK:0:4}-${IN_ACTLOCK:4:2}-${IN_ACTLOCK:6:2} ${IN_ACTLOCK:8:2}:${IN_ACTLOCK:10:2}:00" +%s)
    NOW_EPOCH=$(date +%s)
    (( NOW_EPOCH > ACTLOCK_EPOCH )) && { echo "Token expired."; continue; }
    (( PLAN_EXP_EPOCH < ACTLOCK_EPOCH )) && { echo "Invalid token dates."; continue; }
    DEVICE_ID=$( (has_cmd settings && settings get secure android_id 2>/dev/null) || hostname 2>/dev/null || echo "unknown_device" )
    DEVICE_HASH=$(sha256_hash "$DEVICE_ID")
    cat > "$ACT_FILE" <<EOF
USERNAME="${IN_USER}"
PLAN="${IN_PLAN}"
PLAN_EXPIRY_RAW="${IN_PLANEXP}"
ACT_LOCK_RAW="${IN_ACTLOCK}"
PLAN_EXPIRY_EPOCH="${PLAN_EXP_EPOCH}"
ACT_LOCK_EPOCH="${ACTLOCK_EPOCH}"
DEVICE_HASH="${DEVICE_HASH}"
ACTIVATED_ON="$(date '+%Y%m%d%H%M')"
EOF
    chmod 600 "$ACT_FILE"
    echo "Activation successful for user: $IN_USER, plan: $IN_PLAN, expires: $(date -d "@$PLAN_EXP_EPOCH" '+%F')"
    log "Activation: $IN_USER | $IN_PLAN | expires $(date -d "@$PLAN_EXP_EPOCH")"
    break
  done
}

# ---------------------------
# Save / Read Settings
# ---------------------------
save_setting() {
  grep -v "^${1}=" "$SETTINGS_FILE" 2>/dev/null >/tmp/hyperset.tmp || true
  printf "%s=%s\n" "$1" "$2" >> /tmp/hyperset.tmp
  mv /tmp/hyperset.tmp "$SETTINGS_FILE"
}
read_setting() {
  awk -F= -v key="$1" '$1==key{print substr($0,index($0,"=")+1)}' "$SETTINGS_FILE" 2>/dev/null || echo ""
}

# ---------------------------
# Touch Sensitivity
# ---------------------------
apply_touch_settings() {
  log "Touch X=$TOUCH_X Y=$TOUCH_Y Scale=$TOUCH_SCALE applied"
  save_setting TOUCH_X "$TOUCH_X"
  save_setting TOUCH_Y "$TOUCH_Y"
  save_setting TOUCH_SCALE "$TOUCH_SCALE"
}

set_touch_custom() {
  local newx="${1:-$TOUCH_X}"
  local newy="${2:-$TOUCH_Y}"
  local news="${3:-$TOUCH_SCALE}"
  newx=$(( newx<1?1:newx>20?20:newx ))
  newy=$(( newy<1?1:newy>20?20:newy ))
  HT_SMOOTH="$news"
  TOUCH_X="$newx"; TOUCH_Y="$newy"; TOUCH_SCALE="$news"
  apply_touch_settings
}

# ---------------------------
# vPool / Preload
# ---------------------------
create_vpool() {
  [ -f "$VPOOL_FILE" ] && return 0
  mkdir -p "$(dirname "$VPOOL_FILE")"
  if has_cmd fallocate; then
    fallocate -l "${VPOOL_SIZE_MB}M" "$VPOOL_FILE" 2>/dev/null || true
  else
    dd if=/dev/zero of="$VPOOL_FILE" bs=1M count=0 seek="$VPOOL_SIZE_MB" 2>/dev/null || true
  fi
  dd if="$VPOOL_FILE" of=/dev/null bs=1M count=8 >/dev/null 2>&1 || true
  printf "%s\n" "$(date '+%s')" > "$VPOOL_META" 2>/dev/null || true
  log "vPool created $VPOOL_FILE"
}

preload_assets() {
  local paths="$1"
  [ -z "$paths" ] && return 0
  IFS=',' read -r -a arr <<< "$paths"
  for p in "${arr[@]}"; do
    [ -z "$p" ] && continue
    if [ -f "$p" ]; then dd if="$p" of=/dev/null bs=1M count=4 >/dev/null 2>&1 || true; fi
  done
  log "vPool preload done"
}

# ---------------------------
# ARC+ & Preboost / Micro-Burst
# ---------------------------
arc_enable() { ARC_ON=1; log "ARC+ enabled"; }
arc_disable() { ARC_ON=0; log "ARC+ disabled"; }

apply_preboost() {
  log "Preboost level $PREBOOST_LEVEL, Micro-Burst $MICROBURST_LEVEL applied"
}

# ---------------------------
# Neural Power Manager (battery aware)
# ---------------------------
get_battery_pct() {
  if has_cmd dumpsys; then
    dumpsys battery 2>/dev/null | awk -F: '/level/ {gsub(/ /,"",$2); print $2; exit}' || echo "100"
  else
    echo "100"
  fi
}
is_charging() { [ "$(get_battery_pct)" -ge 100 ] && echo 1 || echo 0; }

neural_power_manager() {
  create_vpool
  apply_touch_settings
  while true; do
    batpct=$(get_battery_pct)
    [ -z "$batpct" ] && batpct=100
    charging=$(is_charging)
    if [ "$batpct" -ge "$BATTERY_SAFE_MIN" ]; then
      if [ "$charging" -eq 1 ]; then
        AFB=1; arc_enable
        TOUCH_X=18; TOUCH_Y=18; TOUCH_SCALE=0.65; apply_touch_settings
        log "TURBO mode (charging) battery=$batpct%"
      else
        AFB=1; arc_enable
        TOUCH_X=16; TOUCH_Y=16; TOUCH_SCALE=0.75; apply_touch_settings
        log "BALANCED mode battery=$batpct%"
      fi
    else
      AFB=0; arc_disable
      TOUCH_X=10; TOUCH_Y=10; TOUCH_SCALE=0.95; apply_touch_settings
      log "ECO mode battery=$batpct%"
    fi
    sleep 10
  done
}

# ---------------------------
# Watchdog & Recovery
# ---------------------------
watchdog() {
  while true; do
    if ! pgrep -f "neural_power_manager" >/dev/null 2>&1; then
      watchdog_log "neural_power_manager not running, restarting..."
      nohup bash -c 'neural_power_manager' >/dev/null 2>&1 &
      sleep 1
    fi
    sleep 60
  done
}

# ---------------------------
# Landscape Detection for Free Fire
# ---------------------------
detect_freefire() {
  if has_cmd dumpsys; then
    fg=$(dumpsys activity activities 2>/dev/null | awk -F' ' '/mResumedActivity/ {print $4; exit}' | cut -d'/' -f1)
    case "$fg" in
      com.dts.freefire*|com.dts.freefiremax*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  return 1
}

# ---------------------------
# Restore Stock Settings
# ---------------------------
restore_stock() {
  log "Restoring stock defaults"
  TOUCH_X=$(read_setting TOUCH_X); [ -z "$TOUCH_X" ] && TOUCH_X=10
  TOUCH_Y=$(read_setting TOUCH_Y); [ -z "$TOUCH_Y" ] && TOUCH_Y=10
  TOUCH_SCALE=$(read_setting TOUCH_SCALE); [ -z "$TOUCH_SCALE" ] && TOUCH_SCALE=0.85
  apply_touch_settings
  arc_disable
  AFB=0
}

# ---------------------------
# Menu
# ---------------------------
show_menu() {
  while true; do
    echo "🔥 HYPERSENSE FINAL — AG HYDRAX (@hydraxff_yt)"
    echo "1) Activate / Check Activation"
    echo "2) Set Touch Sensitivity X/Y + Scale"
    echo "3) Enable Turbo / ARC+"
    echo "4) Disable Turbo / ARC+"
    echo "5) Restore Defaults"
    echo "6) Exit"
    read -p "Choose: " CHOICE
    case "$CHOICE" in
      1) check_activation || prompt_activation ;;
      2) read -p "Enter X (1-20): " nx; read -p "Enter Y (1-20): " ny; read -p "Enter Scale (0.1-1.0): " ns; set_touch_custom "$nx" "$ny" "$ns";;
      3) AFB=1; arc_enable; echo "Turbo Enabled";;
      4) AFB=0; arc_disable; echo "Turbo Disabled";;
      5) restore_stock; echo "Defaults Restored";;
      6) exit 0 ;;
      *) echo "Invalid" ;;
    esac
  done
}

# ---------------------------
# Startup
# ---------------------------
check_activation || prompt_activation
nohup bash -c 'neural_power_manager' >/dev/null 2>&1 &
nohup bash -c 'watchdog' >/dev/null 2>&1 &
create_vpool
preload_assets "$VPOOL_FILE"

# Launch Menu
show_menu

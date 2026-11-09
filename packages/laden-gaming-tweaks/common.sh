# Laden OS gaming tweaks: shared helpers (sourced by root helper + guard).
# Loads defaults, then the first matching hardware profile, then /etc/laden/gaming.conf.
LADEN_HW_DIR=/usr/share/laden/gaming/hw
RAPL=/sys/class/powercap/intel-rapl:0
STATE=/run/laden-perf

load_profile() {
  # defaults: generic machine, no power-limit management, no clock cap
  HW_PROFILE=generic
  GAME_PL1_W=""; GAME_PL1_MIN_W=""; GAME_PL1_MAX_W=""; GAME_PL2_W=""; PL1_STEP_W=5
  CPU_HOT_C=95; CPU_COOL_C=85; GPU_HOT_C=84; GPU_COOL_C=76
  PCORE_CAP_KHZ=""; GUARD_INTERVAL=3; PPD_PROFILE=performance
  SCX_SCHED=lavd; SCX_MODE=gaming
  local vendor product f
  vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
  product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
  for f in "$LADEN_HW_DIR"/*.conf; do
    [[ -r $f ]] || continue
    local MATCH_VENDOR="" MATCH_PRODUCT=""
    eval "$(grep -E '^MATCH_(VENDOR|PRODUCT)=' "$f")"
    if [[ -n $MATCH_VENDOR && $vendor =~ $MATCH_VENDOR && $product =~ ${MATCH_PRODUCT:-.} ]]; then
      . "$f"; HW_PROFILE=$(basename "$f" .conf); break
    fi
  done
  [[ -r /etc/laden/gaming.conf ]] && . /etc/laden/gaming.conf
  [[ -d $RAPL ]] || GAME_PL1_W=""
  return 0
}

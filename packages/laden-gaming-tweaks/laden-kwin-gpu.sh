# Laden OS: on hybrid laptops, let KWin render on the GPU that drives the external
# monitors. Otherwise every frame of a game shown on a dGPU-wired monitor is copied
# dGPU -> iGPU (compositing) -> dGPU (scanout). Applies at login.
# Off switch: KWIN_PRIMARY=igpu in /etc/laden/gaming.conf, or touch ~/.config/laden/kwin-igpu
if [ -z "${KWIN_DRM_DEVICES:-}" ]; then
  _lk_mode=auto
  [ -r /etc/laden/gaming.conf ] && _lk_v=$(sed -n 's/^KWIN_PRIMARY=\([a-z]*\).*/\1/p' /etc/laden/gaming.conf | tail -n1) && [ -n "$_lk_v" ] && _lk_mode=$_lk_v
  [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/laden/kwin-igpu" ] && _lk_mode=igpu
  _lk_d=""; _lk_i=""; _lk_ext=0
  for _lk_c in /sys/class/drm/card[0-9] /sys/class/drm/card[0-9][0-9]; do
    [ -e "$_lk_c/device/driver" ] || continue
    _lk_drv=$(basename "$(readlink -f "$_lk_c/device/driver")")
    case "$_lk_drv" in
      nvidia) _lk_d=/dev/dri/${_lk_c##*/}
              for _lk_s in "$_lk_c"-*/status; do [ "$(cat "$_lk_s" 2>/dev/null)" = connected ] && _lk_ext=1; done ;;
      i915|xe|amdgpu) [ -z "$_lk_i" ] && _lk_i=/dev/dri/${_lk_c##*/} ;;
    esac
  done
  if [ -n "$_lk_d" ] && [ -n "$_lk_i" ] && [ -e "$_lk_d" ] && [ -e "$_lk_i" ]; then
    if [ "$_lk_mode" = dgpu ] || { [ "$_lk_mode" = auto ] && [ "$_lk_ext" = 1 ]; }; then
      export KWIN_DRM_DEVICES="$_lk_d:$_lk_i"
    fi
  fi
  unset _lk_mode _lk_v _lk_d _lk_i _lk_ext _lk_c _lk_drv _lk_s
fi

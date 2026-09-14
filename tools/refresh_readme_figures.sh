#!/usr/bin/env bash
# Copy the current figures from HPT_DATA_DIR/output/figures into docs/figures/
# for the README, scaled to 1600 px wide (macOS sips; plain copy elsewhere).
#
# The figures show national and state aggregates derived from Trilliant Health
# data. They are committed only because this repository is private; do not make
# the repository public, or share these images, without Trilliant's permission
# (terms of service 2.3(i), 2.3(iii)).
#
# Usage: tools/refresh_readme_figures.sh   (run from the repository root)
set -euo pipefail
src="${HPT_DATA_DIR:-/Volumes/MufflySamsung 1/hpt_prices}/output/figures"
dest="docs/figures"
mkdir -p "$dest"
figures=(
  geo2_colonoscopy_state_ranks
  geo1_colonoscopy_commercial_medicaid_maps
  addon_threshold_minutes_B
  addon_threshold_utilization_B
  addon_day_capacity
  addon_threshold_minutes_A
  addon_threshold_utilization_A
  addon_tornado
  ownership_forest
  supp_geo3_colonoscopy_medicare_advantage_map
  supp_geo4_colonoscopy_ma_state_ranks
  supp_geo5_colonoscopy_system_weighting
  birth1_vaginal_ranks
  birth1_cesarean_ranks
  birth2_cesarean_premium
  birth3_vaginal_maps
  birth4_midwifery_presence
)
for f in "${figures[@]}"; do
  [ -f "$src/$f.png" ] || { echo "missing $src/$f.png" >&2; exit 1; }
  if command -v sips >/dev/null 2>&1; then
    sips --resampleWidth 1600 "$src/$f.png" --out "$dest/$f.png" >/dev/null
  else
    cp "$src/$f.png" "$dest/$f.png"
  fi
done
echo "copied ${#figures[@]} figures to $dest"
du -sh "$dest"

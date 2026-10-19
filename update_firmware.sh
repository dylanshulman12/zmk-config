#!/usr/bin/env bash
# Dactyl Manuform left half (6 cols x 6 rows, 34 keys) for nice!nano v2 + ZMK.
# Run from inside your ZMK config repo:   bash update_firmware.sh
# If the repo has more than one shield, name it:   bash update_firmware.sh onekey
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ---------- find the shield ----------
SHIELD="${1:-}"
if [[ -n "$SHIELD" ]]; then
  mapfile -t overlays < <(find . -path ./.git -prune -o -path '*/boards/shields/*' -name "$SHIELD.overlay" -print)
else
  mapfile -t overlays < <(find . -path ./.git -prune -o -path '*/boards/shields/*' -name '*.overlay' -print)
fi

if [[ ${#overlays[@]} -eq 0 ]]; then
  echo "ERROR: no shield .overlay found under boards/shields/. Run this from your ZMK config repo." >&2
  exit 1
fi
if [[ ${#overlays[@]} -gt 1 ]]; then
  echo "More than one shield found. Rerun with the one you want, e.g. bash update_firmware.sh onekey" >&2
  printf '  %s\n' "${overlays[@]}" >&2
  exit 1
fi

OVERLAY="${overlays[0]}"
SHIELD="$(basename "$OVERLAY" .overlay)"
SHIELD_DIR="$(dirname "$OVERLAY")"

# Any keymap with this shield's name (shield folder and/or config/) gets replaced.
mapfile -t keymaps < <(find . -path ./.git -prune -o -name "$SHIELD.keymap" -print)
if [[ ${#keymaps[@]} -eq 0 ]]; then
  keymaps=("$SHIELD_DIR/$SHIELD.keymap")
fi

echo "Shield:  $SHIELD"
echo "Overlay: $OVERLAY"
printf 'Keymap:  %s\n' "${keymaps[@]}"

# ---------- back up originals outside the repo ----------
BACKUP="$HOME/zmk-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in "$OVERLAY" "${keymaps[@]}"; do
  [[ -f "$f" ]] && cp "$f" "$BACKUP/$(echo "${f#./}" | tr '/' '_')"
done
echo "Backups: $BACKUP"

# ---------- overlay: pins + matrix ----------
cat > "$OVERLAY" <<'EOF'
#include <dt-bindings/zmk/matrix_transform.h>

/ {
    chosen {
        zmk,kscan = &kscan0;
        zmk,matrix-transform = &default_transform;
    };

    kscan0: kscan {
        compatible = "zmk,kscan-gpio-matrix";
        diode-direction = "col2row";

        // Columns -> bottom C pad (nano left side)
        col-gpios
            = <&gpio0 17 GPIO_ACTIVE_HIGH>   // col 0  017  Esc Tab Shift Ctrl Gui
            , <&gpio0 20 GPIO_ACTIVE_HIGH>   // col 1  020  1 Q A Z Alt
            , <&gpio0 22 GPIO_ACTIVE_HIGH>   // col 2  022  2 W S X [ Home
            , <&gpio0 24 GPIO_ACTIVE_HIGH>   // col 3  024  3 E D C ] End
            , <&gpio1 0  GPIO_ACTIVE_HIGH>   // col 4  100  4 R F V Space Lower
            , <&gpio0 11 GPIO_ACTIVE_HIGH>   // col 5  011  5 T G B Bksp Del
            ;

        // Rows -> side R pad (nano right side)
        row-gpios
            = <&gpio0 31 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>   // row 0  031  number row
            , <&gpio0 29 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>   // row 1  029  Tab Q W E R T
            , <&gpio0 2  (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>   // row 2  002  Shift A S D F G
            , <&gpio1 15 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>   // row 3  115  Ctrl Z X C V B
            , <&gpio1 13 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>   // row 4  113  Gui Alt [ ] Space Bksp
            , <&gpio1 11 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>   // row 5  111  Home End Lower Del
            ;
    };

    default_transform: keymap_transform_0 {
        compatible = "zmk,matrix-transform";
        columns = <6>;
        rows = <6>;
        map = <
            RC(0,0) RC(0,1) RC(0,2) RC(0,3) RC(0,4) RC(0,5)
            RC(1,0) RC(1,1) RC(1,2) RC(1,3) RC(1,4) RC(1,5)
            RC(2,0) RC(2,1) RC(2,2) RC(2,3) RC(2,4) RC(2,5)
            RC(3,0) RC(3,1) RC(3,2) RC(3,3) RC(3,4) RC(3,5)
            RC(4,0) RC(4,1) RC(4,2) RC(4,3) RC(4,4) RC(4,5)
                            RC(5,2) RC(5,3) RC(5,4) RC(5,5)
        >;
    };
};
EOF

# ---------- keymap ----------
TMP_KEYMAP="$(mktemp)"
cat > "$TMP_KEYMAP" <<'EOF'
#include <behaviors.dtsi>
#include <dt-bindings/zmk/keys.h>
#include <dt-bindings/zmk/bt.h>

/ {
    keymap {
        compatible = "zmk,keymap";

        base {
            bindings = <
                &kp ESC    &kp N1   &kp N2    &kp N3    &kp N4     &kp N5
                &kp TAB    &kp Q    &kp W     &kp E     &kp R      &kp T
                &kp LSHFT  &kp A    &kp S     &kp D     &kp F      &kp G
                &kp LCTRL  &kp Z    &kp X     &kp C     &kp V      &kp B
                &kp LGUI   &kp LALT &kp LBKT  &kp RBKT  &kp SPACE  &kp BSPC
                                    &kp HOME  &kp END   &mo 1      &kp DEL
            >;
        };

        lower {
            bindings = <
                &kp GRAVE    &kp F1       &kp F2       &kp F3     &kp F4     &kp F5
                &bt BT_SEL 0 &bt BT_SEL 1 &bt BT_SEL 2 &kp UP     &trans     &trans
                &bt BT_CLR   &trans       &kp LEFT     &kp DOWN   &kp RIGHT  &trans
                &trans       &trans       &trans       &trans     &trans     &trans
                &trans       &trans       &trans       &trans     &trans     &trans
                                          &kp PG_UP    &kp PG_DN  &trans     &trans
            >;
        };
    };
};
EOF

for k in "${keymaps[@]}"; do
  cp "$TMP_KEYMAP" "$k"
done
rm -f "$TMP_KEYMAP"

# ---------- sanity check ----------
if [[ -f build.yaml ]] && ! grep -q "shield: *$SHIELD" build.yaml; then
  echo "WARNING: build.yaml doesn't mention shield '$SHIELD'. Check it before pushing." >&2
fi

echo
echo "Done. Now run:"
echo "  git add -A && git commit -m \"Dactyl left half 6x6 matrix\" && git push"

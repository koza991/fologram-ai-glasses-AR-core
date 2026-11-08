#!/system/bin/sh
# TEMPORARY: present the device as OnePlus 6 (16 MP IMX519 main camera, 4608x3456, mounted at 90°).
# Use this only if YOUR sensor orientation is 90°; on a 270° sensor the image will be upside down.
# Requires Magisk (resetprop). A full reboot restores everything.
D=OnePlus6; M="ONEPLUS A6003"; B=OnePlus; MF=OnePlus
FP="OnePlus/OnePlus6/OnePlus6:8.1.0/OPM1.171019.011/06140300:user/release-keys"
DESC="OnePlus6-user 8.1.0 OPM1.171019.011 06140300 release-keys"

command -v resetprop >/dev/null || { echo "resetprop not found (Magisk required)"; exit 1; }
for part in "" system. vendor. odm. product. system_ext. bootimage. vendor_dlkm.; do
  resetprop -n "ro.product.${part}device" "$D"
  resetprop -n "ro.product.${part}model" "$M"
  resetprop -n "ro.product.${part}name" "$D"
  resetprop -n "ro.product.${part}brand" "$B"
  resetprop -n "ro.product.${part}manufacturer" "$MF"
  resetprop -n "ro.${part}build.fingerprint" "$FP"
done
resetprop -n ro.build.product "$D"
resetprop -n ro.build.description "$DESC"
pm clear com.google.ar.core >/dev/null 2>&1
echo "Now: $(getprop ro.product.device) / $(getprop ro.product.model)"
echo "Restarting Android framework in 3 s (≈30 s). Reboot the device to undo."
sleep 3
setprop ctl.restart zygote

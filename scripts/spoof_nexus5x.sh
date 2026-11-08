#!/system/bin/sh
# TEMPORARY: present the device as Google Nexus 5X (bullhead) so ARCore loads a profile.
# Nexus 5X's rear camera is mounted at 270°, matching INMO Air3.
# Requires Magisk (resetprop). A full reboot restores everything.
#   su -c "sh /data/local/tmp/spoof_nexus5x.sh"
D=bullhead; M="Nexus 5X"; B=google; MF=LGE
FP="google/bullhead/bullhead:8.1.0/OPM7.181205.001/5080180:user/release-keys"
DESC="bullhead-user 8.1.0 OPM7.181205.001 5080180 release-keys"

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
pm clear com.google.ar.core >/dev/null 2>&1   # drop cached "unsupported" state
echo "Now: $(getprop ro.product.device) / $(getprop ro.product.model)"
echo "Restarting Android framework in 3 s (≈30 s). Reboot the device to undo."
sleep 3
setprop ctl.restart zygote

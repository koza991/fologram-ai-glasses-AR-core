#!/system/bin/sh
# Diagnose why Fologram's AR features don't work. Open Fologram first, wait ~20 s, then run:
#   adb shell sh /data/local/tmp/diag_arcore.sh      (root gives more detail: su -c "...")
L=/data/local/tmp/arcore_diag.txt
logcat -d > $L 2>&1

echo "current model: $(getprop ro.product.device) / $(getprop ro.product.model)"
echo "ARCore installed: $(pm list packages com.google.ar.core | grep -c ar.core)"
echo "ARCore feature declared: $(pm list features | grep -c camera.ar)"
echo
echo "ProfileDownloadActivity launches : $(grep -c ProfileDownloadActivity $L)   (>0 = no device profile)"
echo "'session was passed NULL' errors : $(grep -c 'session was passed NULL' $L)   (>0 = AR session not created)"
echo "BAD_INPUT capture-session errors : $(grep -c 'BAD_INPUT' $L)   (>0 = profile's stream sizes unsupported)"
echo "'Last visual features at: 0 ns'  : $(grep -c 'Last visual features at: 0 ns' $L)   (>0 = no camera frames reach ARCore)"
echo "Play: UNAVAILABLE_DEVICE_HARDWARE : $(grep -c 'UNAVAILABLE_DEVICE_HARDWARE' $L)"
echo
echo "== recent camera clients"
dumpsys media.camera 2>/dev/null | grep -E 'CONNECT|DISCONNECT|EVICT' | head -4
rm -f $L

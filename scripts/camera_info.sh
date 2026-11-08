#!/system/bin/sh
# Print the camera facts that decide which ARCore-certified device profile can work.
# Run on the device as root:  su -c "sh /data/local/tmp/camera_info.sh"
F=/data/local/tmp/cam_dump.txt
dumpsys media.camera > $F 2>&1

grep -m1 "Number of camera devices" $F
for k in android.lens.facing android.sensor.orientation android.lens.info.availableFocalLengths \
         android.sensor.info.physicalSize android.sensor.info.pixelArraySize \
         android.info.supportedHardwareLevel android.sensor.info.timestampSource \
         android.lens.info.minimumFocusDistance; do
  echo "== $k"
  grep -A1 "$k (" $F | sed -n 2p
done

echo "== output sizes per format (35=YUV_420_888, 34=PRIVATE, 33=JPEG)"
awk '/android.scaler.availableStreamConfigurations \(/{f=1;next} f&&/^ *android\./{f=0} f' $F \
  | grep OUTPUT | awk '{print $1, $2"x"$3}' | tr -d '[' | sort -u \
  | awk '{a[$1]=a[$1]" "$2} END{for(k in a) print "fmt "k":"a[k]}'

echo "== fps ranges"
grep -A3 'android.control.aeAvailableTargetFpsRanges (' $F | sed -n '2,4p'
echo "== IMU"
dumpsys sensorservice | grep -iE "accelerometer\(1\)|gyroscope\(4\)" | head -2
rm -f $F

# Fologram on Android AR Glasses (without official ARCore support)

**English** | [简体中文](README.zh-CN.md)

Run [Fologram](https://fologram.com) — the mixed-reality viewer for Rhino / Grasshopper — on Android-based standalone AR glasses such as the **INMO Air3**, including a workaround for devices that are **not on Google's ARCore supported-devices list**.

---

## ⚠️ Disclaimer

- This repository **does not contain** any Fologram or Google ARCore packages. Obtain them yourself from legitimate sources.
- Changing device model properties is unofficial. It may conflict with service terms, reduce tracking accuracy, break some system features, or affect your warranty. **Use at your own risk.**
- The method here is **temporary only**: a reboot fully restores the device. No system partition is modified.

---

## 1. Why Google Play says "not compatible"

Fologram's Android manifest marks two things as **required**:

- `android.hardware.camera.ar` (declared only by devices certified for Google ARCore)
- `com.google.ar.core` (Google Play Services for AR)

Most AR glasses are not ARCore-certified, so the Play Store hides the app or refuses to install it.

## 2. Install Fologram (no root needed)

Requirements: [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools) (adb) on your computer, and **USB debugging** enabled on the glasses.

1. Get the Fologram Android package yourself. Recent versions are usually an **XAPK** (base APK + a `config.arm64_v8a` split).
2. An XAPK is just a zip. Extract it and install all APKs together with `install-multiple`:

```bash
adb install-multiple -r -g com.fologram.android.apk config.arm64_v8a.apk
```

Or use [`scripts/install_fologram.sh`](scripts/install_fologram.sh):

```bash
./scripts/install_fologram.sh path/to/Fologram.xapk
```

3. Install **Google Play Services for AR** (`com.google.ar.core`). Pick an officially signed build that matches your device's architecture (arm64) and Android version:

```bash
adb install -r -g google-play-services-for-ar.apk
```

At this point Fologram opens and you can sign in, but **AR features (QR scanning, placing models) do not work yet**.

## 3. Diagnose why AR doesn't work

Run [`scripts/diag_arcore.sh`](scripts/diag_arcore.sh) with Fologram open:

```bash
adb push scripts/diag_arcore.sh /data/local/tmp/ && adb shell sh /data/local/tmp/diag_arcore.sh
```

What the log signatures mean:

| Log signature | Meaning |
|---|---|
| ARCore repeatedly opens `ProfileDownloadActivity`, which closes immediately | Google has no device profile (calibration data) for this model; the download fails |
| `session_lite_c_api.cc ... session was passed NULL` (dozens per second) | The AR session was never created |
| No Fologram `CONNECT` entries in the camera service | The camera is never opened, so QR scanning does nothing |
| Play Store log shows `restriction=UNAVAILABLE_DEVICE_HARDWARE` | Google has officially classified the device as not supporting ARCore |

**Root cause**: at runtime ARCore loads a per-device profile (camera intrinsics, IMU-to-camera relationship, etc.) keyed by the model code (`ro.product.device`). No profile → no session. This is described in Google's [ARCore OEM device certification](https://developers.google.com/ar/develop/device-certification) docs. Sideloading ARCore alone cannot fix it.

## 4. Workaround: temporarily present the device as a certified model (root / Magisk required)

Idea: use Magisk's `resetprop` to **temporarily** change the model, brand and build fingerprint to those of an ARCore-certified device, then soft-restart the Android framework so ARCore loads that device's profile.

### 4.1 Read your own camera parameters first

```bash
adb push scripts/camera_info.sh /data/local/tmp/ && adb shell su -c "sh /data/local/tmp/camera_info.sh"
```

Pay attention to:

- **Sensor orientation**: `android.sensor.orientation` (90 or 270)
- **Supported YUV output sizes** (`fmt 35`)
- Focal length and sensor size (these determine the field of view)

### 4.2 Choosing the right device to imitate is critical

Results measured on INMO Air3: a single 16 MP rear camera, sensor orientation **270°**. It supports 4608×3456, 4000×3000, 1920×1080 and 640×480, but **not** 4032×3024.

| Imitated as | Result | Reason |
|---|---|---|
| Model only, fingerprint unchanged | ❌ Profile download still fails | ARCore also checks that `ro.build.fingerprint` matches the model |
| Pixel 6a (bluejay) + fingerprint | ❌ Session is created, but camera setup fails with `CaptureSessionErrorEvent(type=BAD_INPUT)` and reconnects every 5 s | The profile requests stream sizes (e.g. 4032×3024) that the camera doesn't support |
| OnePlus 6 (OnePlus6) + fingerprint | ⚠️ Runs, but the **image is upside down** and tracking is unstable | OnePlus 6's rear camera is mounted at 90°; the glasses use 270°, a 180° mismatch |
| **Nexus 5X (bullhead) + fingerprint** | ✅ Session OK, camera stays open, QR scan connects | Nexus 5X's rear camera is also mounted **upside down at 270°** |

**Selection rules**:
1. The sensor orientation must match. This is what decides whether the image direction and tracking are correct.
2. Every stream size the profile requests must be supported by your camera.
3. The **fingerprint** must be changed as well.

### 4.3 Manual test (undone by reboot)

```bash
adb push scripts/spoof_nexus5x.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/spoof_nexus5x.sh"
# The UI soft-restarts for about 30 s; then open Fologram
```

Another candidate: [`spoof_oneplus6.sh`](scripts/spoof_oneplus6.sh), for devices whose sensor orientation is 90°.

**To restore**: just reboot the device.

### 4.4 One-tap Magisk toggle (recommended)

[`magisk-module/fologram_ar_toggle`](magisk-module/fologram_ar_toggle) is a module that **does nothing at boot**. You switch it on manually only when you need it:

1. Build: zip all files inside the `fologram_ar_toggle` folder. Paths inside the zip must use `/`, and scripts must have LF line endings. You can also use [`scripts/build_module.sh`](scripts/build_module.sh).
2. Magisk → Modules → Install from storage → reboot once.
3. When you need AR: Magisk → Modules → "Fologram AR toggle (临时开关)" → tap **Action**.
4. To get the original model back: reboot the device.

## 5. QR scanning tips

Fologram's QR pipeline is: ARCore session → `TryAcquireLatestCpuImage` grabs a low-resolution CPU frame (about 640×480) → the built-in ZXing library decodes it. Through a wide-angle glasses camera the QR code covers only a small part of the frame, so:

- maximise the QR code window in Rhino;
- keep the glasses about **25–40 cm** from the screen and hold still for 2–3 seconds;
- avoid screen glare;
- even on an iPhone this scanner is picky about distance, so retry a few times.

## 6. Known limitations

- The imitated device's calibration (field of view, IMU-to-camera extrinsics) doesn't exactly match the glasses, so models may drift slightly.
- While imitating, the whole device reports itself as a Nexus 5X. Vendor apps, system updates and the Play Store may misbehave until you reboot.
- Glasses with different firmware or hardware revisions may have different camera parameters. Check them yourself with step 4.1 first.

## Repository layout

```
scripts/
  install_fologram.sh   extract an XAPK and install-multiple
  diag_arcore.sh        diagnose ARCore session / camera state
  camera_info.sh        read camera orientation / sizes / focal length
  spoof_nexus5x.sh      temporarily imitate Nexus 5X (recommended, 270° sensor)
  spoof_oneplus6.sh     temporarily imitate OnePlus 6 (90° sensor)
  build_module.sh       package the Magisk module
magisk-module/
  fologram_ar_toggle/   Magisk "Action" button toggle
```

## License

[MIT](LICENSE). Fologram, ARCore, INMO and the device names mentioned here are trademarks of their respective owners. This project is not affiliated with any of them.

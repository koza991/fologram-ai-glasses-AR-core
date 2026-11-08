# Fologram on Android AR Glasses (without official ARCore support)

[English](README.md) | **简体中文**

在 **INMO Air3** 等安卓一体式 AR 眼镜上运行 [Fologram](https://fologram.com)（Rhino / Grasshopper 的混合现实查看器），包括**设备不在 Google ARCore 支持名单时**的调整方法。


---

## ⚠️ 免责声明

- 本仓库**不包含**任何 Fologram 或 Google ARCore 的安装包，请自行从合法渠道获取。
- 修改设备型号属性属于非官方用法，可能违反相关服务条款，可能导致追踪精度下降、部分系统功能异常或影响保修。**风险自负。**
- 本方法只做**临时**修改，重启设备即可完全恢复，不改动系统分区。

---

## 1. 为什么 Google Play 显示"设备不支持"

Fologram 安卓版的清单文件把以下两项设为**必需**：

- `android.hardware.camera.ar`（只有通过 Google ARCore 认证的设备才会声明）
- `com.google.ar.core`（Google Play Services for AR）

大多数 AR 眼镜没有通过 ARCore 认证，所以 Play 商店直接隐藏或拒绝安装。

## 2. 安装 Fologram（无需 root）

需要：电脑安装 [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools)（adb），眼镜打开 **USB 调试**。

1. 自行获取 Fologram 安卓版安装包。最新版通常是 **XAPK**（基础包 + `config.arm64_v8a` 分包）。
2. XAPK 实际是 zip，解压后用 `install-multiple` 一起安装：

```bash
adb install-multiple -r -g com.fologram.android.apk config.arm64_v8a.apk
```

或者用 [`scripts/install_fologram.sh`](scripts/install_fologram.sh)：

```bash
./scripts/install_fologram.sh path/to/Fologram.xapk
```

3. 安装 **Google Play Services for AR**（`com.google.ar.core`，选与设备匹配的 arm64 / Android 版本的官方签名包）：

```bash
adb install -r -g google-play-services-for-ar.apk
```

到这一步，Fologram 可以打开、登录，但**扫码 / 放置模型等 AR 功能不能用**。

## 3. 诊断：为什么 AR 不工作

运行 [`scripts/diag_arcore.sh`](scripts/diag_arcore.sh)（需要 Fologram 处于打开状态）：

```bash
adb push scripts/diag_arcore.sh /data/local/tmp/ && adb shell sh /data/local/tmp/diag_arcore.sh
```

常见现象及含义：

| 日志特征 | 含义 |
|---|---|
| ARCore 反复弹出 `ProfileDownloadActivity` 后立刻关闭 | Google 没有该型号的设备配置（校准参数），下载失败 |
| `session_lite_c_api.cc ... session was passed NULL`（每秒几十次） | AR 会话没有建立 |
| 摄像头服务里从来没有 Fologram 的 `CONNECT` 记录 | 摄像头没被打开，扫码当然无反应 |
| Play 商店日志 `restriction=UNAVAILABLE_DEVICE_HARDWARE` | Google 官方判定该设备不支持 ARCore |

**原因**：ARCore 在运行时根据型号代码（`ro.product.device`）加载设备配置文件（摄像头内参、IMU 与摄像头的相对关系等）。没有配置 → 不创建会话。这一点在 Google 的 [ARCore OEM 设备认证文档](https://developers.google.com/ar/develop/device-certification) 里有说明。手动装 ARCore 不能解决这个问题。

## 4. 调整方法：临时伪装为已认证机型（需要 root / Magisk）

思路：用 Magisk 的 `resetprop` **临时**把型号、品牌、系统指纹改成某台已认证的设备，然后软重启 Android 框架，让 ARCore 加载那台设备的配置。

### 4.1 先读取你自己设备的摄像头参数

```bash
adb push scripts/camera_info.sh /data/local/tmp/ && adb shell su -c "sh /data/local/tmp/camera_info.sh"
```

重点看：

- **传感器朝向** `android.sensor.orientation`（90 或 270）
- **支持的 YUV 分辨率**（`fmt 35`）
- 焦距 / 传感器尺寸（决定视场角）

### 4.2 选对"伪装对象"很关键

在 INMO Air3（单颗 16MP 后摄、传感器朝向 **270°**、支持 4608×3456 / 4000×3000 / 1920×1080 / 640×480，**不支持** 4032×3024）上的实测结果：

| 伪装成 | 结果 | 原因 |
|---|---|---|
| 只改型号，不改指纹 | ❌ 仍然下载配置失败 | ARCore 也会检查 `ro.build.fingerprint` 是否与型号一致 |
| Pixel 6a（bluejay）+ 指纹 | ❌ 会话建立了，但摄像头配置报 `CaptureSessionErrorEvent(type=BAD_INPUT)`，每 5 秒重连 | 配置文件请求的分辨率（如 4032×3024）摄像头不支持 |
| OnePlus 6（OnePlus6）+ 指纹 | ⚠️ 能运行，但**画面上下颠倒**，追踪不稳定 | 一加 6 后摄朝向 90°，眼镜是 270°，差 180° |
| **Nexus 5X（bullhead）+ 指纹** | ✅ 会话正常、摄像头持续工作、可以扫码连接 | Nexus 5X 后摄同样是 **270° 倒装** |

**选择规则**：
1. 传感器朝向要一致（这是画面方向和追踪是否正确的关键）；
2. 对方配置请求的分辨率你的摄像头要支持；
3. 必须同时修改**指纹**。

### 4.3 手动测试（重启即恢复）

```bash
adb push scripts/spoof_nexus5x.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/spoof_nexus5x.sh"
# 界面会软重启约 30 秒；之后打开 Fologram
```

其他候选脚本：[`spoof_oneplus6.sh`](scripts/spoof_oneplus6.sh)（适合传感器朝向 90° 的设备）。

**恢复**：直接重启设备。

### 4.4 Magisk 一键开关（推荐）

[`magisk-module/fologram_ar_toggle`](magisk-module/fologram_ar_toggle) 是一个**开机不自动生效**的模块，只在你需要时手动开启：

1. 打包：在 `fologram_ar_toggle` 目录内把所有文件压缩为 zip（注意 zip 内部路径要用 `/`，脚本必须是 LF 换行）。也可以用 [`scripts/build_module.sh`](scripts/build_module.sh)。
2. Magisk → 模块 → 从本地安装 → 重启一次。
3. 需要 AR 时：Magisk → 模块 → 「Fologram AR toggle (临时开关)」→ 点 **操作**。
4. 想恢复原型号：重启设备。

## 5. 扫码小技巧

Fologram 扫码流程是：ARCore 会话 → `TryAcquireLatestCpuImage` 取一帧低分辨率 CPU 图像（约 640×480）→ 内置 ZXing 解码。广角眼镜摄像头下二维码在画面中很小，所以：

- 把 Rhino 里的二维码窗口放到最大；
- 眼镜距屏幕约 **25–40 cm**，保持 2–3 秒不动；
- 避免屏幕反光；
- 即使在 iPhone 上，这个扫码对距离也比较挑剔，多试几次。

## 6. 已知限制

- 伪装设备的校准参数（视场角、IMU-摄像头外参）与眼镜不完全一致，模型可能出现轻微漂移。
- 伪装期间整台设备型号显示为 Nexus 5X，厂商自带应用、系统更新、Play 商店可能表现异常 —— 用完重启即可。
- 不同固件/硬件版本的眼镜，摄像头参数可能不同，请先按 4.1 自查。

## 目录

```
scripts/
  install_fologram.sh   解压 XAPK 并 install-multiple
  diag_arcore.sh        诊断 ARCore 会话/摄像头状态
  camera_info.sh        读取摄像头朝向/分辨率/焦距
  spoof_nexus5x.sh      临时伪装为 Nexus 5X（推荐，270° 传感器）
  spoof_oneplus6.sh     临时伪装为 OnePlus 6（90° 传感器）
  build_module.sh       打包 Magisk 模块
magisk-module/
  fologram_ar_toggle/   Magisk「操作」按钮开关
```

## License

[MIT](LICENSE)。Fologram、ARCore、INMO 及文中提到的设备名称均为其各自所有者的商标，本项目与它们无关联。

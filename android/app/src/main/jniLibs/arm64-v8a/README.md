# libcactus.so placeholder

This directory should contain the `libcactus.so` native library for Android arm64-v8a.

## How to get libcactus.so

### Option 1 — Download pre-built (recommended)
Check the Cactus releases on GitHub:
https://github.com/cactus-compute/cactus/releases

Look for `libcactus.so` in the Android arm64-v8a assets.

### Option 2 — Build from source
```bash
git clone https://github.com/cactus-compute/cactus.git
cd cactus
cactus build --flutter --platform android --arch arm64
```
Then copy the output `libcactus.so` here.

## After adding libcactus.so

1. Place it at: `android/app/src/main/jniLibs/arm64-v8a/libcactus.so`
2. Run `flutter build apk` or `flutter run`
3. The app will automatically use it — no code changes needed.

## Without libcactus.so (current state)

The app runs in **Demo Mode** — the CactusService provides realistic simulated
responses for testing the UI and flow. Everything works except real on-device
inference.

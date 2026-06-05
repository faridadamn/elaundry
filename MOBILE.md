# eLaundry Mobile

Project ini memakai Capacitor untuk membungkus file HTML eLaundry menjadi aplikasi Android.

## Persiapan

- Node.js LTS
- JDK 21
- Android SDK atau Android Studio

## Perintah

```bash
npm install
npm run sync
cd android
gradlew.bat assembleDebug
```

APK debug akan dibuat di:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

Untuk membuka project di Android Studio:

```bash
npm run open:android
```

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase / FCM — processes android/app/google-services.json
    id("com.google.gms.google-services")
}

android {
    namespace = "com.mubtaathub.app"
    // Compile against API 36 — required by geolocator_android, record_android,
    // shared_preferences_android and sqflite_android. compileSdk only controls
    // which SDK stubs the code is compiled against; runtime behavior is
    // governed by targetSdk below, so this is safe on Android 14/15 devices.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time APIs on older
        // Android versions via desugaring).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mubtaathub.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Pinned to 34 (Android 14) to dodge the Android 15 (API 35) emulator
        // GMS Core crash: "NetworkCapability 37 out of range" in
        // PushMessagingRegistrarChimeraProxy.onBind. Targeting 34 keeps the
        // app under the Android 14 behavior contract (off the API-35+
        // networking path the bundled Play Services build mishandles) while
        // compileSdk = 36 satisfies plugin compilation. The most reliable fix
        // is still to run on an API 34 emulator image; this is the build-side
        // mitigation. Note: Play Store new-submission policy requires raising
        // targetSdk before public release.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // R8 (on by default for release) was shrinking away Google Play
            // Services classes — e.g. FusedLocationProviderClient used by the
            // geolocator plugin — because no -keep rules are present. That
            // caused an immediate startup crash on release builds:
            //   java.lang.VerifyError: ... 'Unresolved Reference:
            //   com.google.android.gms.location.FusedLocationProviderClient'
            // Disable shrinking/obfuscation for a reliable build. APK size is
            // dominated by native libraries anyway. Re-enable with proper
            // -keep rules (a proguard-rules.pro) before a public Play release.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backport of java.time / etc. required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

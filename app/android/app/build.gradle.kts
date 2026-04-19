plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lifestream.learn.lifestream_learn_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lifestream.learn.lifestream_learn_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Slice F: `dev` and `prod` flavors. `dev` runs on localhost over
    // cleartext (mostly 10.0.2.2 talking to the emulator host) so we
    // wire `usesCleartextTraffic=true` onto the dev manifest only.
    // `prod` strips that permission and enables minify.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            // Distinct applicationId so a dev + prod install can coexist
            // on the same device without stepping on one another.
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("prod") {
            dimension = "env"
        }
    }

    buildTypes {
        release {
            // Debug keys for now so `flutter run --release` works on
            // unsigned CI builds. Production signing is a TODO — see the
            // README "Build flavors" section.
            signingConfig = signingConfigs.getByName("debug")
            // Enable R8/ProGuard across all release variants; the
            // `proguard-android-optimize.txt` that ships with AGP is a
            // safe default and the Flutter Gradle plugin adds its own
            // keep rules on top.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            // Dev-path debug: no minify, no shrink — fast builds.
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

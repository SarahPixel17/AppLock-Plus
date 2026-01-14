plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.applockplus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // ✅ Explicitly set correct NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ Enable Java 8+ API support
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
        freeCompilerArgs += "-Xlint:-options" // ✅ Suppress obsolete Java 8 warnings
    }

    defaultConfig {
        applicationId = "com.example.applockplus"

        // ✅ Explicitly override Flutter’s default minimum SDK to fix usage_stats issue
        minSdk = 22
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ✅ Using debug signing config for now (change for release builds)
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ✅ Suppress additional compile warnings globally (for all KotlinCompile tasks)
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            freeCompilerArgs += "-Xlint:-options"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ FIXED: Updated to version 2.1.4 (required by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

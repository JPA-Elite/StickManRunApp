import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Release signing from android/key.properties (gitignored — never share
    // it or the .jks publicly). Falls back to debug keys when absent so
    // `flutter run --release` still works on machines without the keystore.
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    val hasReleaseKeys = keystorePropertiesFile.exists()
    if (hasReleaseKeys) {
        FileInputStream(keystorePropertiesFile).use { stream ->
            keystoreProperties.load(stream)
        }
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Note: plain "stickmanrun_app" is rejected by Android (an
        // applicationId must contain at least one dot).
        applicationId = "com.stickmanrun.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeys) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties — debug keys so `flutter run --release`
                // still works.
                signingConfigs.getByName("debug")
            }
        }
    }

    // Every release build also produces stickman-run.apk (a copy of
    // app-release.apk) using only core Gradle APIs.
    tasks.register<Copy>("copyReleaseApk") {
        from(layout.buildDirectory.dir("app/outputs/flutter-apk"))
        include("app-release.apk")
        rename("app-release.apk", "stickman-run.apk")
        into(layout.buildDirectory.dir("app/outputs/flutter-apk"))
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Hooked after evaluation: variant tasks (assembleRelease) only exist then.
afterEvaluate {
    tasks.named("assembleRelease") {
        finalizedBy("copyReleaseApk")
    }
}

flutter {
    source = "../.."
}

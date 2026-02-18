import org.gradle.api.JavaVersion

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter Gradle Plugin должен быть ПОСЛЕ android/kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.outfit_assistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.outfit_assistant"
        minSdk = 21
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

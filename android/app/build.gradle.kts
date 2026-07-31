plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")   // <-- ADD THIS
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.company.bantaydagat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable support for Java 8+ features
        isCoreLibraryDesugaringEnabled = true
        // Set these to 17 to match your JVM target
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.company.bantaydagat"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // This version matches the requirements of your newer plugins
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
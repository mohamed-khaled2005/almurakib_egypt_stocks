import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // ✅ Firebase Google Services
    id("com.google.gms.google-services")
}

// ✅ Read keystore properties (android/key.properties)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProps = keystorePropertiesFile.exists()

if (hasKeystoreProps) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.almurakib.egyptappstocks"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.almurakib.egyptappstocks"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ✅ Release signing config
    signingConfigs {
        create("release") {
            if (hasKeystoreProps) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storePassword = keystoreProperties.getProperty("storePassword")
                // storeFile value comes from key.properties (relative to android/app)
                storeFile = file(keystoreProperties.getProperty("storeFile"))
            }
        }
    }

    buildTypes {
        release {
            // ✅ Use release keystore if available; otherwise fallback to debug (to avoid build failure)
            signingConfig = if (hasKeystoreProps) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // اختياري: لو مش عايز تصغير/ضغط
            isMinifyEnabled = false
            isShrinkResources = false

            // لو عندك proguard-rules.pro (غالباً موجود في android/app/)
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

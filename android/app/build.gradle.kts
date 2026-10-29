import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystoreProperties = Properties()
val releaseKeystorePropertiesFile = rootProject.file("key.properties")
val releaseSigningFileExists = releaseKeystorePropertiesFile.exists().also { exists ->
    if (exists) {
        releaseKeystorePropertiesFile.inputStream().use(releaseKeystoreProperties::load)
    }
}

fun releaseSigningValue(name: String): String? {
    val value = releaseKeystoreProperties.getProperty(name)?.trim() ?: return null
    return if (value.startsWith("env:")) {
        System.getenv(value.removePrefix("env:"))?.takeIf { it.isNotBlank() }
    } else {
        value.takeIf { it.isNotBlank() }
    }
}

val hasReleaseSigning =
    releaseSigningFileExists &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .all { releaseSigningValue(it) != null }
val requireReleaseSigning =
    System.getenv("MAPLOV_REQUIRE_RELEASE_SIGNING")?.equals("true", ignoreCase = true) == true

if (requireReleaseSigning && !hasReleaseSigning) {
    throw GradleException(
        "Production signing is required. Copy android/key.properties.example to " +
            "android/key.properties and configure the MapLov upload keystore " +
            "and its referenced environment variables.",
    )
}

android {
    namespace = "ca.maplov.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ca.maplov.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseSigningValue("keyAlias")
                keyPassword = releaseSigningValue("keyPassword")
                storeFile = file(releaseSigningValue("storeFile")!!)
                storePassword = releaseSigningValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // CI may compile an unsigned release bundle. A distributable build
            // must set MAPLOV_REQUIRE_RELEASE_SIGNING=true and provide the
            // ignored android/key.properties file.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val profileDataDir = File(System.getenv("USERPROFILE") ?: System.getProperty("user.home"), "AppData/Local/Fisio360")
val codexDataDir = File(System.getenv("USERPROFILE") ?: System.getProperty("user.home"), "AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/Fisio360")
val signingDataDir = System.getenv("FISIO_DATA_DIR")?.let { File(it) }
    ?: listOf(profileDataDir, codexDataDir).firstOrNull { File(it, "android-signing.properties").exists() }
    ?: profileDataDir
val signingFile = File(signingDataDir, "android-signing.properties")
val signingProperties = Properties()
if (signingFile.exists()) {
    FileInputStream(signingFile).use { signingProperties.load(it) }
}
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }) {
    require(signingFile.exists()) { "Configure a assinatura em AppData/Local/Fisio360 antes de gerar release." }
}

android {
    namespace = "com.example.fisio_360"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fisio_360"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                storeFile = file(System.getenv("FISIO_SIGNING_KEY") ?: signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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

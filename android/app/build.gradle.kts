import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.gradle.api.GradleException
import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFileCandidates =
    listOf(
        rootProject.file("key.properties"),
        file("../key.properties"),
        file("key.properties"),
    )
val keystorePropertiesFile = keystorePropertiesFileCandidates.firstOrNull { it.exists() }
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile != null) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")?.trim()
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")?.trim()
val configuredStoreFile = keystoreProperties.getProperty("storeFile")?.trim()
val releaseStorePassword = keystoreProperties.getProperty("storePassword")?.trim()
val releaseStoreFile =
    configuredStoreFile
        ?.takeIf { it.isNotEmpty() }
        ?.let { path ->
            val direct = File(path)
            val candidates =
                listOf(
                    if (direct.isAbsolute) direct else file(path),
                    rootProject.file(path),
                    file("../$path"),
                    file("../../$path"),
                )
            candidates.firstOrNull { it.exists() }
        }
val releaseStoreFileCandidates =
    configuredStoreFile
        ?.takeIf { it.isNotEmpty() }
        ?.let { path ->
            listOf(
                file(path).absolutePath,
                rootProject.file(path).absolutePath,
                file("../$path").absolutePath,
                file("../../$path").absolutePath,
            )
        }
        ?: emptyList()
val hasRequiredSigningValues =
    !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !configuredStoreFile.isNullOrBlank()
val hasReleaseKeystore =
    keystorePropertiesFile != null &&
        hasRequiredSigningValues &&
        releaseStoreFile?.exists() == true
val requestedTasks = gradle.startParameter.taskNames
val isReleaseTaskRequested =
    requestedTasks.any { task ->
        task.contains("release", ignoreCase = true) || task.contains("bundle", ignoreCase = true)
    }

if (isReleaseTaskRequested && !hasReleaseKeystore) {
    throw GradleException(
        "Release signing is not configured correctly.\n" +
            "key.properties candidates: ${keystorePropertiesFileCandidates.joinToString()} \n" +
            "resolved key.properties: ${keystorePropertiesFile?.absolutePath ?: "not found"} \n" +
            "storeFile in key.properties: ${configuredStoreFile ?: "missing"} \n" +
            "storeFile candidates: ${releaseStoreFileCandidates.joinToString()} \n" +
            "resolved storeFile: ${releaseStoreFile?.absolutePath ?: "not found"}"
    )
}

android {
    namespace = "com.albuhaira.nipras"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.albuhaira.nipras"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore && releaseStoreFile != null) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

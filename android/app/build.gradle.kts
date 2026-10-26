import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Passwords stay in the environment, never in Gradle properties or arguments.
val releaseSigning = listOf(
    "ANDROID_KEYSTORE_PATH",
    "ANDROID_KEYSTORE_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it) }
val hasReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }

android {
    namespace = "com.zanzibarr.zanzibarr"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zanzibarr.zanzibarr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseSigning.getValue("ANDROID_KEYSTORE_PATH")!!)
                storePassword = releaseSigning.getValue("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = releaseSigning.getValue("ANDROID_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")
        }
    }
}

val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        check(hasReleaseSigning) {
            "Release builds require ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
                "ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD. See docs/ANDROID_SIGNING.md."
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// unrar C++ runtime paylaşımlı libc++ kullanır; libc++_shared.so NDK'dan
// her ABI için jniLibs'e kopyalanır (yoksa dlopen "libc++_shared.so not
// found" ile düşer). NDK dizini sürümden bağımsız çözülür.
val localSdkProperties = Properties().apply {
    rootProject.file("local.properties").takeIf { it.isFile }?.inputStream()?.use { load(it) }
}
val pinnedSdkHome = System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT")
    ?: localSdkProperties.getProperty("sdk.dir")
val ndkHome: String? = System.getenv("ANDROID_NDK_HOME")
    ?: System.getenv("ANDROID_NDK_ROOT")
    ?: pinnedSdkHome?.let { home -> File("$home/ndk/${android.ndkVersion}").absolutePath }
val llvmHostTag = when {
    System.getProperty("os.name").startsWith("Windows", true) -> "windows-x86_64"
    System.getProperty("os.name").startsWith("Mac", true) ->
        if (System.getProperty("os.arch") == "aarch64") "darwin-arm64" else "darwin-x86_64"
    else -> "linux-x86_64"
}
val libcxxAbis = mapOf(
    "arm64-v8a" to "aarch64-linux-android",
    "armeabi-v7a" to "arm-linux-androideabi",
    "x86" to "i686-linux-android",
    "x86_64" to "x86_64-linux-android",
)
// AGP SourceSet Provider kabul etmez; dizin somutlaştırılır.
val libcxxOut = layout.buildDirectory.dir("libcxx/jniLibs").get().asFile
val copyLibcxxShared = tasks.register("copyLibcxxShared") {
    doLast {
        check(ndkHome != null) { "The pinned Android NDK is required; see docs/BUILD_TOOLCHAINS.md" }
        val properties = Properties().apply {
            File("$ndkHome/source.properties").inputStream().use { load(it) }
        }
        check(properties.getProperty("Pkg.Revision") == android.ndkVersion) { "ANDROID_NDK_HOME differs from the pinned NDK" }
        libcxxAbis.forEach { (abi, triple) ->
            val src = File(
                "$ndkHome/toolchains/llvm/prebuilt/$llvmHostTag/sysroot/usr/lib/$triple/libc++_shared.so",
            )
            if (src.exists()) {
                val dst = File(libcxxOut, "$abi/libc++_shared.so")
                dst.parentFile.mkdirs()
                src.copyTo(dst, overwrite = true)
            } else {
                logger.warn("libc++_shared.so bulunamadı: ${src.absolutePath}")
            }
        }
    }
}
android.sourceSets.getByName("main").jniLibs.srcDir(libcxxOut)
tasks.named("preBuild").configure { dependsOn(copyLibcxxShared) }

dependencies {
    // OTA güncelleme: indirilen APK'yı sistem yükleyicisine veren FileProvider.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}

// ✅ Root-level Gradle for Flutter + Firebase (compatible with AGP 8.9.1)

plugins {
    // Match the version already bundled with Flutter (no version override)
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false

    // Firebase plugin (must match flutterfire version)
    id("com.google.gms.google-services") version "4.3.15" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Keep build structure consistent with Flutter
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

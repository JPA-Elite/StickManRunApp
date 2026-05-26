allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    if (project.name == "flutter_native_timezone") {
        // AGP 8+ fails if the library's manifest still contains a legacy `package="..."`
        // attribute. Remove it before `processDebugManifest`.
        val patchFlutterNativeTimezoneManifest = tasks.register(
            "patchFlutterNativeTimezoneManifest"
        ) {
            doLast {
                val manifest = project.projectDir.resolve("src/main/AndroidManifest.xml")
                if (!manifest.exists()) return@doLast

                val original = manifest.readText()
                // Remove `package="..."`
                val updated =
                    original.replace(Regex("""\s+package="[^"]+""""), "")
                if (updated != original) {
                    manifest.writeText(updated)
                }
            }
        }

        tasks.matching {
            it.name == "processDebugManifest" || it.name == "processReleaseManifest"
        }.configureEach {
            dependsOn(patchFlutterNativeTimezoneManifest)
        }

        // Set namespace + force consistent JVM target (fix:
        // "Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks")
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                namespace = "com.example.flutter_app.flutter_native_timezone"
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }

        plugins.withId("org.jetbrains.kotlin.android") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions {
                        jvmTarget.set(
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                        )
                    }
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

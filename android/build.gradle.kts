import com.android.build.gradle.BaseExtension
import org.gradle.api.JavaVersion
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/**
 * ✅ Выравниваем JVM target для ВСЕХ android-модулей (app + plugins).
 * Важно: НЕ используем options.release (он ломает AGP, как у тебя было со sqflite).
 */
subprojects {

    // Android compileOptions (Java)
    plugins.withId("com.android.application") {
        extensions.configure<BaseExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    plugins.withId("com.android.library") {
        extensions.configure<BaseExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    // Kotlin jvmTarget = 17
    tasks.withType(KotlinCompile::class.java).configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

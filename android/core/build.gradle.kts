plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.serialization.json)
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
    useJUnitPlatform()
    // The Nepal sightline tests read the packed data. They skip when it is missing.
    systemProperty("himal.data", rootProject.projectDir.parentFile.resolve("shared/data").absolutePath)
}

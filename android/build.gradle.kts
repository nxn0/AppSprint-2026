import org.gradle.api.Project
import org.gradle.api.ProjectEvaluationListener
import org.gradle.api.ProjectState

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
}

gradle.addListener(object : ProjectEvaluationListener {
    override fun beforeEvaluate(project: Project) = Unit

    override fun afterEvaluate(project: Project, state: ProjectState) {
        project.extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.let {
            it.compileSdk = 36
        }
    }
})

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

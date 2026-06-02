package name.jurgenei.gradle.antlr;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.gradle.api.plugins.JavaPluginExtension;
import org.gradle.api.tasks.SourceSet;
import org.gradle.api.tasks.SourceSetContainer;

/**
 * Registers a PL/SQL-specific XML AST task type preconfigured from {@link XmlAstPlsqlGradleTask}.
 */
public final class XmlAstPlsqlPlugin implements Plugin<Project> {

    /**
     * Creates the PL/SQL XML AST plugin.
     */
    public XmlAstPlsqlPlugin() {
    }

    @Override
    public void apply(final Project project) {
        project.getTasks().register("plsqlXmlAst", XmlAstPlsqlGradleTask.class, task -> {
            task.setGroup("xmlast");
            task.setDescription("Convert PL/SQL file trees to XML AST output.");
        });

        project.getPlugins().withId("java", plugin -> {
            final JavaPluginExtension javaPluginExtension = project.getExtensions().getByType(JavaPluginExtension.class);
            final SourceSetContainer sourceSets = javaPluginExtension.getSourceSets();
            final SourceSet mainSourceSet = sourceSets.getByName(SourceSet.MAIN_SOURCE_SET_NAME);

            project.getTasks().withType(XmlAstPlsqlGradleTask.class).configureEach(task -> {
                task.getRuntimeClasspath().from(mainSourceSet.getRuntimeClasspath());
                task.dependsOn(project.getTasks().named("classes"));
            });
        });
    }
}


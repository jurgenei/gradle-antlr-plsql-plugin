package name.jurgenei.grammars.plsql;

import org.gradle.api.Plugin;
import org.gradle.api.Project;

/**
 * Marker Gradle plugin used to validate publication metadata for this module.
 */
public final class PlsqlGrammarPlugin implements Plugin<Project> {

    /**
     * Creates the marker plugin instance.
     */
    public PlsqlGrammarPlugin() {
    }

    @Override
    public void apply(Project project) {
        // Intentionally no-op: this module primarily publishes grammar artifacts.
    }
}


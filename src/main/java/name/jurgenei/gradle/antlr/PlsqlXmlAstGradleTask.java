package name.jurgenei.grammars.plsql;

import org.gradle.api.model.ObjectFactory;

import javax.inject.Inject;

/**
 * Legacy compatibility task type for PL/SQL XML AST conversion.
 */
@Deprecated(forRemoval = false)
public abstract class PlsqlXmlAstGradleTask extends XmlAstPlsqlGradleTask {

    /**
     * Creates the legacy compatibility task type.
     *
     * @param objects Gradle object factory used by the parent task.
     */
    @Inject
    public PlsqlXmlAstGradleTask(final ObjectFactory objects) {
        super(objects);
    }
}


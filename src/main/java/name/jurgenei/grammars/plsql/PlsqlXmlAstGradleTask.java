package name.jurgenei.grammars.plsql;

import org.gradle.api.model.ObjectFactory;

import javax.inject.Inject;

/**
 * Legacy compatibility task type for PL/SQL XML AST conversion.
 */
@Deprecated(forRemoval = false)
public abstract class PlsqlXmlAstGradleTask extends XmlAstPlsqlGradleTask {

    @Inject
    public PlsqlXmlAstGradleTask(final ObjectFactory objects) {
        super(objects);
    }
}


package example.classpath;

import org.apache.commons.lang3.StringUtils;

public class ClasspathApp {
    public String message() {
        return "classpath: " + StringUtils.capitalize( "apache commons" );
    }
}
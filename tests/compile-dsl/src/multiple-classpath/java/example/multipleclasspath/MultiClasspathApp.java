package example.multipleclasspath;

import example.App;
import org.apache.commons.lang3.StringUtils;

public class MultiClasspathApp {
    public String message() {
        return "multiple: " + new App().message() + " / " + StringUtils.capitalize( "apache commons" );
    }
}
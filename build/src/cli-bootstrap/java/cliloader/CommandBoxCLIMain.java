package cliloader;

import java.io.File;
import java.net.URL;
import java.net.URLClassLoader;

/**
 * Launches the adjacent BoxLang runtime with the CommandBox CLI module.
 */
public class CommandBoxCLIMain {

	/**
	 * Loads the adjacent BoxLang JAR and forwards the command-line arguments.
	 *
	 * @param arguments The command-line arguments supplied to the launcher.
	 * @throws Exception If the runtime cannot be loaded or invoked.
	 */
	public static void main( String[] arguments ) throws Exception {
		var launcherLocation = CommandBoxCLIMain.class.getProtectionDomain().getCodeSource().getLocation();
		var launcherDirectory = new File( launcherLocation.toURI() ).getParentFile();
		var boxLangJar = new File( launcherDirectory, "boxlang.jar" );
		var boxLangLoader = new URLClassLoader(
			new URL[] { boxLangJar.toURI().toURL() },
			CommandBoxCLIMain.class.getClassLoader()
		);
		var boxRunner = Class.forName( "ortus.boxlang.runtime.BoxRunner", true, boxLangLoader );
		var main = boxRunner.getMethod( "main", String[].class );
		var forwardedArguments = new String[ arguments.length + 1 ];
		forwardedArguments[ 0 ] = "cli";
		System.arraycopy( arguments, 0, forwardedArguments, 1, arguments.length );
		main.invoke( null, (Object) forwardedArguments );
	}

}
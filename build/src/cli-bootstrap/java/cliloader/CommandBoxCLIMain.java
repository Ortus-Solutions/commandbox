package cliloader;

import java.io.FileInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.Arrays;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Bootstraps BoxLang and launches the installed runtime with the CommandBox CLI module.
 */
public class CommandBoxCLIMain {

	private static final String INSTALLER_ARCHIVE = "boxlang-installer.zip";
	private static final String BOXLANG_VERSION = "boxlang-version";
	private static final String BOXLANG_JAR = "boxlang.jar";
	private static final String MINISERVER_JAR = "boxlang-miniserver.jar";
	private static final String SYSTEM_MODULES_ARCHIVE = "commandbox-system-modules.zip";
	private static final String COMMANDBOX_HOME_PROPERTY = "CommandBox_home";
	private static final String BOXLANG_HOME_PROPERTY = "boxlang.home";
	private static final String BOXLANG_INSTALL_HOME_PROPERTY = "boxlang.install.home";
	private static final String BOXLANG_HOME_ENVIRONMENT = "BOXLANG_HOME";
	private static final String BOXLANG_INSTALL_HOME_ENVIRONMENT = "BOXLANG_INSTALL_HOME";
	private static final String BVM_HOME_ENVIRONMENT = "BVM_HOME";
	private static boolean debugEnabled;

	/**
	 * Installs BoxLang when needed, then launches the installed runtime and forwards the arguments.
	 *
	 * @param arguments The command-line arguments supplied to the launcher.
	 * @throws Exception If the runtime cannot be loaded or invoked.
	 */
	public static void main( String[] arguments ) throws Exception {
		debugEnabled = containsDebugFlag( arguments );
		debug( "CLI Java Version: " + System.getProperty( "java.vm.version", System.getProperty( "java.version", "Unknown" ) ) );
		debug( "CLI Java Home: " + System.getProperty( "java.home", "Unknown" ) );
		debug( "CLI Java Vendor: " + System.getProperty( "java.vendor", "Unknown" ) );
		debug( "Operating system: " + System.getProperty( "os.name", "Unknown" ) + " (Windows: " + isWindows() + ")" );
		debug( "Initial arguments: " + Arrays.toString( arguments ) );
		arguments = removeDebugFlag( arguments );
		debug( "Forwarded arguments: " + Arrays.toString( arguments ) );
		applyJavaProperties();
		debug( "BVM_HOME: " + getEnvironmentIgnoreCase( BVM_HOME_ENVIRONMENT ) );
		debug( "BOXLANG_INSTALL_HOME: " + getEnvironmentIgnoreCase( BOXLANG_INSTALL_HOME_ENVIRONMENT ) );
		debug( "BOXLANG_HOME: " + getEnvironmentIgnoreCase( BOXLANG_HOME_ENVIRONMENT ) );
		debug( "PATH: " + getEnvironmentIgnoreCase( "PATH" ) );
		var launcherLocation = CommandBoxCLIMain.class.getProtectionDomain().getCodeSource().getLocation();
		var launcherDirectory = new File( launcherLocation.toURI() ).getParentFile();
		debug( "Launcher directory: " + launcherDirectory.getAbsolutePath() );
		var commandBoxHome = resolveCommandBoxHome( arguments, launcherDirectory );
		debug( "CommandBox home: " + commandBoxHome.getAbsolutePath() );
		System.setProperty( COMMANDBOX_HOME_PROPERTY, commandBoxHome.getAbsolutePath() );
		arguments = removeArgument( arguments, COMMANDBOX_HOME_PROPERTY );
		debug( "Arguments after bootstrap options: " + Arrays.toString( arguments ) );
		var systemBoxJson = commandBoxHome.toPath().resolve( "cfml/box.json" );
		if ( Files.notExists( systemBoxJson ) ) {
			if ( !commandBoxHome.mkdirs() ) {
				if ( !commandBoxHome.isDirectory() ) {
					throw new IOException( "Unable to create CommandBox home: " + commandBoxHome );
				}
			}
			extractSystemModules( commandBoxHome.toPath() );
		}
		var boxLangHome = resolveBoxLangHome( launcherDirectory );
		debug( "BoxLang runtime home: " + boxLangHome.getAbsolutePath() );
		var boxLang = detectBoxLang( launcherDirectory );
		if ( boxLang == null ) {
			var boxLangInstallHome = resolveInstallerInstallHome( launcherDirectory );
			debug( "BoxLang was not detected; installing to: " + boxLangInstallHome.getAbsolutePath() );
			installBoxLang( boxLangInstallHome, boxLangHome );
			boxLang = new BoxLangInstallation( getExecutable( boxLangInstallHome ), "installer default" );
		}
		extractBxCliModule( boxLangHome.toPath(), boxLang.executable() );
		createBoxLauncher( boxLang.executable() );
		launchBoxLang( boxLang.executable(), boxLangHome, commandBoxHome, arguments, boxLang.source() );
	}

	/**
	 * Applies semicolon-delimited JVM properties supplied through BOX_JAVA_PROPS.
	 */
	private static void applyJavaProperties() {
		var javaProperties = System.getenv( "BOX_JAVA_PROPS" );
		debug( "BOX_JAVA_PROPS: " + ( javaProperties == null ? "<not set>" : javaProperties ) );
		if ( javaProperties == null || javaProperties.isBlank() ) {
			return;
		}
		for ( var property : javaProperties.split( ";" ) ) {
			var separator = property.indexOf( '=' );
			if ( separator > 0 ) {
				System.setProperty( property.substring( 0, separator ), property.substring( separator + 1 ) );
				debug( "Applied JVM property: " + property.substring( 0, separator ) + "=" + property.substring( separator + 1 ) );
			} else {
				debug( "Ignored malformed BOX_JAVA_PROPS entry: " + property );
			}
		}
	}

	/**
	 * Resolves the CommandBox home using command-line, adjacent properties, environment, and default values.
	 *
	 * @param arguments Launcher arguments.
	 * @param launcherDirectory Directory containing the launcher.
	 * @return Resolved CommandBox home.
	 * @throws IOException If adjacent properties cannot be read.
	 */
	private static File resolveCommandBoxHome( String[] arguments, File launcherDirectory ) throws IOException {
		var commandLineHome = findArgumentValue( arguments, COMMANDBOX_HOME_PROPERTY );
		debug( "CommandBox home command-line value: " + commandLineHome );
		if ( commandLineHome != null ) {
			return resolveHome( commandLineHome, launcherDirectory );
		}

		var adjacentProperties = loadAdjacentProperties( launcherDirectory );
		debug( "Adjacent properties: " + adjacentProperties );
		var propertiesHome = getPropertyIgnoreCase( adjacentProperties, "cli.home" );
		if ( propertiesHome == null ) {
			propertiesHome = getPropertyIgnoreCase( adjacentProperties, COMMANDBOX_HOME_PROPERTY );
		}
		if ( propertiesHome != null ) {
			return resolveHome( propertiesHome, launcherDirectory );
		}

		var environmentHome = getEnvironmentIgnoreCase( COMMANDBOX_HOME_PROPERTY );
		debug( "CommandBox home environment value: " + environmentHome );
		if ( environmentHome != null ) {
			return resolveHome( environmentHome, launcherDirectory );
		}
		var systemHome = getPropertyIgnoreCase( System.getProperties(), COMMANDBOX_HOME_PROPERTY );
		debug( "CommandBox home JVM property value: " + systemHome );
		if ( systemHome != null ) {
			return resolveHome( systemHome, launcherDirectory );
		}
		var defaultHome = System.getProperty( "user.home" );
		return defaultHome == null ? launcherDirectory : new File( defaultHome, ".CommandBox" );
	}

	/**
	 * Loads commandbox.properties or cli.properties beside the launcher.
	 *
	 * @param launcherDirectory Directory containing the launcher.
	 * @return Loaded properties, or an empty set when neither file exists.
	 * @throws IOException If the properties file cannot be read.
	 */
	private static Properties loadAdjacentProperties( File launcherDirectory ) throws IOException {
		var properties = new Properties();
		var commandBoxProperties = new File( launcherDirectory, "commandbox.properties" );
		var cliProperties = new File( launcherDirectory, "cli.properties" );
		var propertiesFile = commandBoxProperties.isFile() ? commandBoxProperties : cliProperties;
		debug( "Checking properties file: " + commandBoxProperties.getAbsolutePath() );
		debug( "Checking properties file: " + cliProperties.getAbsolutePath() );
		if ( propertiesFile.isFile() ) {
			debug( "Loading properties file: " + propertiesFile.getAbsolutePath() );
			try ( var input = new FileInputStream( propertiesFile ) ) {
				properties.load( input );
			}
		}
		return properties;
	}

	/**
	 * Resolves the directory containing the installed BoxLang binaries and JARs.
	 *
	 * @param commandBoxHome Resolved CommandBox home.
	 * @return BoxLang installation home.
	 */
	private static File resolveInstallerInstallHome( File launcherDirectory ) throws IOException {
		var environmentHome = getEnvironmentIgnoreCase( BOXLANG_INSTALL_HOME_ENVIRONMENT );
		if ( environmentHome != null ) {
			return new File( environmentHome );
		}
		var adjacentProperties = loadAdjacentProperties( launcherDirectory );
		var configuredHome = getPropertyIgnoreCase( adjacentProperties, BOXLANG_INSTALL_HOME_PROPERTY );
		if ( configuredHome != null ) {
			return resolveHome( configuredHome, launcherDirectory );
		}
		return isWindows() ? new File( "C:\\boxlang" ) : new File( "/usr/local/boxlang" );
	}

	/**
	 * Detects BoxLang according to the platform-specific environment and PATH precedence.
	 *
	 * @return Detected installation, or null when installation is required.
	 * @throws IOException If PATH lookup cannot be executed.
	 * @throws InterruptedException If PATH lookup is interrupted.
	 */
	private static BoxLangInstallation detectBoxLang( File launcherDirectory ) throws IOException, InterruptedException {
		var bvmHome = getEnvironmentIgnoreCase( BVM_HOME_ENVIRONMENT );
		var installHome = getEnvironmentIgnoreCase( BOXLANG_INSTALL_HOME_ENVIRONMENT );
		var boxLangHome = getEnvironmentIgnoreCase( BOXLANG_HOME_ENVIRONMENT );
		var configuredHome = getPropertyIgnoreCase( System.getProperties(), BOXLANG_HOME_PROPERTY );
		var configuredInstallHome = getPropertyIgnoreCase( System.getProperties(), BOXLANG_INSTALL_HOME_PROPERTY );
		var adjacentProperties = loadAdjacentProperties( launcherDirectory );
		var adjacentInstallHome = getPropertyIgnoreCase( adjacentProperties, BOXLANG_INSTALL_HOME_PROPERTY );
		debug( "BVM_HOME: " + bvmHome );
		debug( "BOXLANG_INSTALL_HOME: " + installHome );
		debug( "BOXLANG_HOME: " + boxLangHome );
		debug( "boxlang.home JVM property: " + configuredHome );
		debug( "boxlang.install.home JVM property: " + configuredInstallHome );
		debug( "boxlang.install.home adjacent property: " + adjacentInstallHome );

		// Check the BVM-managed current installation first because it selects the active BoxLang version.
		if ( bvmHome != null ) {
			return findInstallation( new File( bvmHome, "current/bin" ), "BVM_HOME" );
		}
		// Check the explicit install home because it directly identifies the BoxLang installation directory.
		if ( installHome != null ) {
			return findInstallation( new File( installHome, "bin" ), "BOXLANG_INSTALL_HOME" );
		}
		// Check the Windows runtime home because its executable lives beside the home subdirectory.
		if ( isWindows() && boxLangHome != null ) {
			var executableDirectory = isWindows() ? new File( boxLangHome, "../bin" ) : new File( boxLangHome, "bin" );
			return findInstallation( executableDirectory, "BOXLANG_HOME" );
		}
		// Check the configured JVM home because it is an explicit local installation override.
		if ( configuredHome != null ) {
			var executableDirectory = isWindows() ? new File( configuredHome, "../bin" ) : new File( configuredHome, "bin" );
			return findInstallation( executableDirectory, "boxlang.home JVM property" );
		}
		// Check the JVM installer-home property because it explicitly identifies a local installation.
		if ( configuredInstallHome != null ) {
			return findInstallation( new File( configuredInstallHome, "bin" ), "boxlang.install.home JVM property" );
		}
		// Check the adjacent installer-home property because it configures this launcher installation.
		if ( adjacentInstallHome != null ) {
			return findInstallation( new File( adjacentInstallHome, "bin" ), "boxlang.install.home adjacent property" );
		}
		// Check PATH last because command lookup starts a child process and is more expensive.
		var pathInstallation = findOnPath();
		debug( pathInstallation == null ? "BoxLang was not found on PATH." : "BoxLang found on PATH: " + pathInstallation.executable() );
		return pathInstallation;
	}

	/**
	 * Checks a specific BoxLang installation directory.
	 *
	 * @param binDirectory Directory containing the platform executable.
	 * @param source Description of the location being checked.
	 * @return Detected installation, or null when the executable is absent.
	 */
	private static BoxLangInstallation findInstallation( File binDirectory, String source ) {
		var executable = new File( binDirectory, isWindows() ? "boxlang.bat" : "boxlang" );
		debug( "Checking " + source + " executable: " + executable.getAbsolutePath() );
		return executable.isFile() ? new BoxLangInstallation( executable, source ) : null;
	}

	/**
	 * Resolves BoxLang from PATH using the operating system's command lookup utility.
	 *
	 * @return Detected installation, or null when PATH does not provide BoxLang.
	 * @throws IOException If the lookup process cannot be started.
	 * @throws InterruptedException If the lookup process is interrupted.
	 */
	private static BoxLangInstallation findOnPath() throws IOException, InterruptedException {
		var command = isWindows() ? List.of( "where.exe", "boxlang" ) : List.of( "sh", "-c", "command -v boxlang" );
		debug( "Checking PATH with: " + command );
		var process = new ProcessBuilder( command ).redirectErrorStream( true ).start();
		var output = new String( process.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8 ).trim();
		var exitCode = process.waitFor();
		debug( "PATH lookup exit code: " + exitCode + ", output: " + output );
		if ( exitCode != 0 || output.isBlank() ) {
			return null;
		}
		var executable = new File( output.split( "\\R" )[ 0 ].trim() );
		return executable.isFile() ? new BoxLangInstallation( executable, "PATH" ) : null;
	}

	/**
	 * Resolves the executable path for a known installer destination.
	 *
	 * @param installHome Installer destination.
	 * @return Platform executable.
	 */
	private static File getExecutable( File installHome ) {
		return new File( installHome, isWindows() ? "bin/boxlang.bat" : "bin/boxlang" );
	}

	/**
	 * Resolves BoxLang's runtime home for configuration, logs, cache, and modules.
	 *
	 * @param launcherDirectory Directory containing the launcher.
	 * @return BoxLang runtime home.
	 * @throws IOException If adjacent properties cannot be read.
	 */
	private static File resolveBoxLangHome( File launcherDirectory ) throws IOException {
		var adjacentProperties = loadAdjacentProperties( launcherDirectory );
		var configuredHome = getPropertyIgnoreCase( adjacentProperties, BOXLANG_HOME_PROPERTY );
		debug( "boxlang.home property: " + configuredHome );
		if ( configuredHome != null ) {
			return resolveHome( configuredHome, launcherDirectory );
		}
		var environmentHome = getEnvironmentIgnoreCase( BOXLANG_HOME_ENVIRONMENT );
		debug( "BOXLANG_HOME: " + environmentHome );
		if ( environmentHome != null ) {
			return new File( environmentHome );
		}
		var systemHome = getPropertyIgnoreCase( System.getProperties(), BOXLANG_HOME_PROPERTY );
		debug( "boxlang.home JVM property: " + systemHome );
		if ( systemHome != null ) {
			return resolveHome( systemHome, launcherDirectory );
		}
		var userHome = System.getProperty( "user.home" );
		return userHome == null ? launcherDirectory : new File( userHome, ".boxlang" );
	}

	/**
	 * Resolves a configured path relative to the launcher when it is not absolute.
	 *
	 * @param value Configured path.
	 * @param launcherDirectory Directory containing the launcher.
	 * @return Resolved path.
	 */
	private static File resolveHome( String value, File launcherDirectory ) {
		var home = new File( value );
		return home.isAbsolute() ? home : new File( launcherDirectory, value );
	}

	/**
	 * Finds an equals-form command-line option without regard to case.
	 *
	 * @param arguments Launcher arguments.
	 * @param name Option name without the leading dash.
	 * @return Option value, or null when absent.
	 */
	private static String findArgumentValue( String[] arguments, String name ) {
		var prefix = "-" + name.toLowerCase( Locale.ROOT ) + "=";
		for ( var argument : arguments ) {
			if ( argument.toLowerCase( Locale.ROOT ).startsWith( prefix ) ) {
				return argument.substring( prefix.length() );
			}
		}
		return null;
	}

	/**
	 * Removes an equals-form bootstrap option before forwarding arguments to CommandBox.
	 *
	 * @param arguments Launcher arguments.
	 * @param name Option name without the leading dash.
	 * @return Arguments without the named option.
	 */
	private static String[] removeArgument( String[] arguments, String name ) {
		var prefix = "-" + name.toLowerCase( Locale.ROOT ) + "=";
		return Arrays.stream( arguments )
			.filter( argument -> !argument.toLowerCase( Locale.ROOT ).startsWith( prefix ) )
			.toArray( String[]::new );
	}

	/**
	 * Reads an environment variable without regard to case.
	 *
	 * @param name Environment variable name.
	 * @return Environment value, or null when absent.
	 */
	private static String getEnvironmentIgnoreCase( String name ) {
		for ( var entry : System.getenv().entrySet() ) {
			if ( entry.getKey().equalsIgnoreCase( name ) ) {
				return entry.getValue();
			}
		}
		return null;
	}

	/**
	 * Reads a map-backed property without regard to key case.
	 *
	 * @param properties Properties map.
	 * @param name Property name.
	 * @return Property value, or null when absent.
	 */
	private static String getPropertyIgnoreCase( Map<?, ?> properties, String name ) {
		for ( var entry : properties.entrySet() ) {
			if ( entry.getKey().toString().equalsIgnoreCase( name ) ) {
				return entry.getValue().toString();
			}
		}
		return null;
	}

	/**
	 * Extracts the bundled platform installer and runs it with explicit noninteractive options.
	 *
	 * @param boxLangInstallHome Directory where the installer places BoxLang binaries and JARs.
	 * @param boxLangHome Runtime home for BoxLang configuration and user data.
	 * @throws IOException If extraction, execution, or installation fails.
	 * @throws InterruptedException If the installer process is interrupted.
	 */
	private static void installBoxLang( File boxLangInstallHome, File boxLangHome ) throws IOException, InterruptedException {
		var resourceName = isWindows() ? "install-boxlang.ps1" : "install-boxlang.sh";
		var temporaryDirectory = Files.createTempDirectory( "commandbox-installer-" );
		var installerDirectory = temporaryDirectory.resolve( "installer" );
		var installerPath = installerDirectory.resolve( resourceName );
		try {
			debug( "Installer archive resource: " + INSTALLER_ARCHIVE );
			debug( "Installer temporary directory: " + temporaryDirectory );
			extractInstallerArchive( installerDirectory );
			if ( Files.notExists( installerPath ) ) {
				throw new IOException( "Missing installer script in archive: " + resourceName );
			}
			var boxLangJar = extractOptionalResource( BOXLANG_JAR, temporaryDirectory );
			var miniServerJar = extractOptionalResource( MINISERVER_JAR, temporaryDirectory );
			var command = new java.util.ArrayList<String>();
			if ( isWindows() ) {
				command.addAll( List.of( "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installerPath.toString() ) );
			} else {
				command.addAll( List.of( "bash", installerPath.toString() ) );
			}
			if ( boxLangJar != null && miniServerJar != null ) {
				command.addAll( List.of(
					"--force", "--non-interactive", "--without-jre", "--without-commandbox",
					"--boxlang-path", boxLangJar.toString(),
					"--miniserver-path", miniServerJar.toString(),
					"--installer-scripts-path", installerDirectory.toString()
				) );
				debug( "Using bundled BoxLang runtime artifacts for offline installation." );
			} else {
				command.addAll( List.of(
					getBoxLangVersion(), "--non-interactive", "--without-jre", "--without-commandbox",
					"--installer-scripts-path", installerDirectory.toString()
				) );
			}
			var processBuilder = new ProcessBuilder( command ).inheritIO();
			debug( "Installer command: " + command );
			debug( "Installer BOXLANG_INSTALL_HOME: " + boxLangInstallHome.getAbsolutePath() );
			debug( "Installer BOXLANG_HOME: " + boxLangHome.getAbsolutePath() );
			processBuilder.environment().put( "BOXLANG_INSTALL_HOME", boxLangInstallHome.getAbsolutePath() );
			processBuilder.environment().put( "BOXLANG_HOME", boxLangHome.getAbsolutePath() );
			var exitCode = processBuilder.start().waitFor();
			debug( "Installer exit code: " + exitCode );
			if ( exitCode != 0 ) {
				throw new IOException( "BoxLang installer failed with exit code " + exitCode );
			}
		} finally {
			deleteDirectory( temporaryDirectory );
		}
	}

	/**
	 * Reads the BoxLang version selected when the launcher was built.
	 *
	 * @return The BoxLang version.
	 * @throws IOException If the bundled version resource cannot be read.
	 */
	private static String getBoxLangVersion() throws IOException {
		try ( var input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( BOXLANG_VERSION ) ) {
			if ( input == null ) {
				return "latest";
			}
			return new String( input.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8 ).trim();
		}
	}

	/**
	 * Copies an optional bundled resource into the installer temporary directory.
	 *
	 * @param resourceName Classpath resource name.
	 * @param destinationDirectory Temporary installer directory.
	 * @return Extracted path, or null when the resource is not bundled.
	 * @throws IOException If the resource cannot be copied.
	 */
	private static Path extractOptionalResource( String resourceName, Path destinationDirectory ) throws IOException {
		try ( var input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( resourceName ) ) {
			if ( input == null ) {
				debug( "Optional installer resource was not bundled: " + resourceName );
				return null;
			}
			var destination = destinationDirectory.resolve( resourceName );
			Files.copy( input, destination, StandardCopyOption.REPLACE_EXISTING );
			debug( "Extracted optional installer resource: " + destination );
			return destination;
		}
	}

	/**
	 * Extracts the bundled bx-cli module zip or installs it with BoxLang's module installer.
	 *
	 * @param boxLangHome BoxLang runtime home directory.
	 * @param boxLangExecutable Resolved BoxLang executable used to locate its installed scripts.
	 * @throws IOException If the JAR resource cannot be read or files cannot be written.
	 * @throws InterruptedException If the module installer process is interrupted.
	 */
	private static void extractBxCliModule( Path boxLangHome, File boxLangExecutable ) throws IOException, InterruptedException {
		var moduleDir = boxLangHome.resolve( "modules/bx-cli" );
		try ( var input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( "bx-cli.zip" ) ) {
			if ( input == null ) {
				installBxCliModule( boxLangHome, boxLangExecutable );
				return;
			}
			try ( var zip = new ZipInputStream( input ) ) {
				ZipEntry entry;
				while ( ( entry = zip.getNextEntry() ) != null ) {
					if ( entry.isDirectory() ) {
						continue;
					}
					var destination = moduleDir.resolve( entry.getName() ).normalize();
					if ( !destination.startsWith( moduleDir ) ) {
						throw new IOException( "Invalid bx-cli module entry: " + entry.getName() );
					}
					Files.createDirectories( destination.getParent() );
					Files.copy( zip, destination, StandardCopyOption.REPLACE_EXISTING );
				}
			}
		}
		debug( "bx-cli module extracted to: " + moduleDir );
	}

	/**
	 * Installs bx-cli through the scripts installed with BoxLang for thin launchers.
	 */
	private static void installBxCliModule( Path boxLangHome, File boxLangExecutable ) throws IOException, InterruptedException {
		var installHome = boxLangExecutable.toPath().toRealPath().getParent().getParent();
		var scriptDirectory = isWindows() ? installHome.resolve( "bin" ) : installHome.resolve( "scripts" );
		var script = scriptDirectory.resolve( isWindows() ? "install-bx-module.ps1" : "install-bx-module.sh" );
		if ( Files.notExists( script ) ) {
			throw new IOException( "BoxLang module installer was not installed: " + script );
		}
		var command = isWindows()
			? List.of( "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script.toString(), "bx-cli" )
			: List.of( "sh", script.toString(), "bx-cli" );
		var processBuilder = new ProcessBuilder( command ).inheritIO();
		processBuilder.environment().put( "BOXLANG_HOME", boxLangHome.toString() );
		processBuilder.environment().put( "BOXLANG_INSTALL_HOME", installHome.toString() );
		var exitCode = processBuilder.start().waitFor();
		if ( exitCode != 0 ) {
			throw new IOException( "BoxLang module installer failed with exit code " + exitCode );
		}
		debug( "bx-cli module installed to: " + boxLangHome.resolve( "modules/bx-cli" ) );
	}

	/**
	 * Creates the CommandBox executable beside the BoxLang executable exposed on PATH.
	 *
	 * @param boxLangExecutable The resolved BoxLang executable.
	 * @throws IOException If the launcher cannot be written.
	 * @throws InterruptedException If PATH lookup is interrupted.
	 */
	private static void createBoxLauncher( File boxLangExecutable ) throws IOException, InterruptedException {
		var boxLangPath = boxLangExecutable.toPath().toRealPath();
		var launcher = boxLangPath.getParent().resolve( isWindows() ? "box.bat" : "box" );
		var executablePath = boxLangPath.toString();
		var contents = isWindows()
			? "@echo off\r\n\"" + executablePath + "\" cli %*\r\n"
			: "#!/bin/sh\nexec \"" + executablePath + "\" cli \"$@\"\n";
		Files.writeString( launcher, contents, java.nio.charset.StandardCharsets.UTF_8 );
		if ( !isWindows() && !launcher.toFile().setExecutable( true, false ) ) {
			throw new IOException( "Unable to make CommandBox launcher executable: " + launcher );
		}
		if ( isWindows() ) {
			debug( "CommandBox launcher created at: " + launcher );
			return;
		}
		var pathInstallation = findOnPath();
		if ( pathInstallation != null ) {
			var systemLauncher = pathInstallation.executable().toPath().getParent().resolve( "box" );
			if ( !systemLauncher.equals( launcher ) ) {
				Files.deleteIfExists( systemLauncher );
				Files.createSymbolicLink( systemLauncher, launcher );
				debug( "CommandBox system link created at: " + systemLauncher );
			}
		}
		debug( "CommandBox launcher created at: " + launcher );
	}

	/**
	 * Extracts bundled CommandBox configuration and modules into a newly created home.
	 *
	 * @param commandBoxHome CommandBox home directory.
	 * @throws IOException If the JAR resource cannot be read or contains an unsafe entry.
	 */
	private static void extractSystemModules( Path commandBoxHome ) throws IOException {
		var cfmlDirectory = commandBoxHome.resolve( "cfml" );
		try ( var input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( SYSTEM_MODULES_ARCHIVE ) ) {
			if ( input == null ) {
				debug( "Optional system modules archive was not bundled: " + SYSTEM_MODULES_ARCHIVE );
				return;
			}
			try ( var zip = new ZipInputStream( input ) ) {
				ZipEntry entry;
				while ( ( entry = zip.getNextEntry() ) != null ) {
					var destination = cfmlDirectory.resolve( entry.getName() ).normalize();
					if ( !destination.startsWith( cfmlDirectory ) ) {
						throw new IOException( "Invalid CommandBox system module entry: " + entry.getName() );
					}
					if ( entry.isDirectory() ) {
						Files.createDirectories( destination );
					} else {
						Files.createDirectories( destination.getParent() );
						Files.copy( zip, destination, StandardCopyOption.REPLACE_EXISTING );
					}
				}
			}
		}
		debug( "CommandBox system modules extracted to: " + cfmlDirectory.resolve( "modules" ) );
	}

	/**
	 * Launches the installed BoxLang executable in CLI mode.
	 *
	 * @param executable BoxLang executable to invoke.
	 * @param boxLangHome Runtime home for BoxLang configuration and user data.
	 * @param commandBoxHome CommandBox home resolved by the launcher.
	 * @param arguments Arguments forwarded to CommandBox.
	 * @param source Source used to detect the executable.
	 * @throws IOException If the executable cannot be found or exits unsuccessfully.
	 * @throws InterruptedException If the process is interrupted.
	 */
	private static void launchBoxLang( File executable, File boxLangHome, File commandBoxHome, String[] arguments, String source ) throws IOException, InterruptedException {
		debug( "BoxLang executable candidate: " + executable.getAbsolutePath() );
		debug( "BoxLang executable source: " + source );
		if ( !executable.isFile() ) {
			throw new IOException( "BoxLang executable was not installed: " + executable );
		}
		var command = new java.util.ArrayList<String>();
		if ( isWindows() ) {
			command.addAll( List.of( "cmd", "/c", executable.getAbsolutePath(), "cli" ) );
		} else {
			command.addAll( List.of( executable.getAbsolutePath(), "cli" ) );
		}
		command.addAll( List.of( arguments ) );
		var processBuilder = new ProcessBuilder( command ).inheritIO();
		debug( "BoxLang command: " + command );
		debug( "BoxLang BOXLANG_HOME: " + boxLangHome.getAbsolutePath() );
		debug( "BoxLang CommandBox_home: " + commandBoxHome.getAbsolutePath() );
		processBuilder.environment().put( "BOXLANG_HOME", boxLangHome.getAbsolutePath() );
		processBuilder.environment().put( COMMANDBOX_HOME_PROPERTY, commandBoxHome.getAbsolutePath() );
		var exitCode = processBuilder.start().waitFor();
		debug( "BoxLang exit code: " + exitCode );
		if ( exitCode != 0 ) {
			throw new IOException( "BoxLang exited with code " + exitCode );
		}
	}

	/**
	 * Safely extracts the bundled installer archive into a temporary directory.
	 *
	 * @param destinationDirectory Temporary extraction directory.
	 * @throws IOException If the resource is missing or contains an unsafe entry.
	 */
	private static void extractInstallerArchive( Path destinationDirectory ) throws IOException {
		debug( "Extracting installer archive to: " + destinationDirectory );
		var resource = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( INSTALLER_ARCHIVE );
		if ( resource == null ) {
			throw new IOException( "Missing launcher resource: " + INSTALLER_ARCHIVE );
		}
		try ( InputStream input = resource ) {
			Files.createDirectories( destinationDirectory );
			try ( var zip = new ZipInputStream( input ) ) {
				ZipEntry entry;
				while ( ( entry = zip.getNextEntry() ) != null ) {
					debug( "Extracting installer entry: " + entry.getName() );
					var destination = destinationDirectory.resolve( entry.getName() ).normalize();
					if ( !destination.startsWith( destinationDirectory ) ) {
						throw new IOException( "Invalid installer archive entry: " + entry.getName() );
					}
					if ( entry.isDirectory() ) {
						Files.createDirectories( destination );
					} else {
						Files.createDirectories( destination.getParent() );
						Files.copy( zip, destination, StandardCopyOption.REPLACE_EXISTING );
					}
				}
			}
		}
	}

	/**
	 * Determines whether the current operating system is Windows.
	 *
	 * @return True for Windows platforms.
	 */
	private static boolean isWindows() {
		return System.getProperty( "os.name", "" ).toLowerCase( Locale.ROOT ).contains( "windows" );
	}

	/**
	 * Checks whether the launcher debug flag was supplied.
	 *
	 * @param arguments Launcher arguments.
	 * @return True when {@code -clidebug} is present.
	 */
	private static boolean containsDebugFlag( String[] arguments ) {
		for ( var argument : arguments ) {
			if ( argument.equalsIgnoreCase( "-clidebug" ) ) {
				return true;
			}
		}
		return false;
	}

	/**
	 * Removes the bootstrap-only debug flag before forwarding arguments to BoxLang.
	 *
	 * @param arguments Launcher arguments.
	 * @return Arguments without {@code -clidebug}.
	 */
	private static String[] removeDebugFlag( String[] arguments ) {
		return Arrays.stream( arguments ).filter( argument -> !argument.equalsIgnoreCase( "-clidebug" ) ).toArray( String[]::new );
	}

	/**
	 * Writes diagnostic information when CLI debugging is enabled.
	 *
	 * @param message Diagnostic message.
	 */
	private static void debug( String message ) {
		if ( debugEnabled ) {
			System.out.println( "[clidebug] " + message );
		}
	}

	/**
	 * Recursively removes a temporary extraction directory.
	 *
	 * @param directory Directory to remove.
	 * @throws IOException If a directory entry cannot be removed.
	 */
	private static void deleteDirectory( Path directory ) throws IOException {
		if ( Files.notExists( directory ) ) {
			return;
		}
		try ( var paths = Files.walk( directory ) ) {
			paths.sorted( ( left, right ) -> right.compareTo( left ) ).forEach( path -> {
				try {
					Files.deleteIfExists( path );
				} catch ( IOException exception ) {
					throw new RuntimeException( exception );
				}
			} );
		}
	}

	/**
	 * Describes a detected BoxLang executable and how it was found.
	 *
	 * @param executable Detected executable.
	 * @param source Detection source.
	 */
	private record BoxLangInstallation( File executable, String source ) {
	}

}
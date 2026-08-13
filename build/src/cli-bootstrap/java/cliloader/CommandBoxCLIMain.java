package cliloader;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Bootstraps BoxLang and launches the installed runtime with the CommandBox CLI module.
 */
public class CommandBoxCLIMain {

	private static final int MINIMUM_JAVA_VERSION = 21;
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
		verifyJavaVersion();
		applyJavaProperties();
		debug( "BVM_HOME: " + getEnvironmentIgnoreCase( BVM_HOME_ENVIRONMENT ) );
		debug( "BOXLANG_INSTALL_HOME: " + getEnvironmentIgnoreCase( BOXLANG_INSTALL_HOME_ENVIRONMENT ) );
		debug( "BOXLANG_HOME: " + getEnvironmentIgnoreCase( BOXLANG_HOME_ENVIRONMENT ) );
		debug( "PATH: " + getEnvironmentIgnoreCase( "PATH" ) );
		File launcherDirectory = new File( CommandBoxCLIMain.class.getProtectionDomain().getCodeSource().getLocation().toURI() ).getParentFile();
		debug( "Launcher directory: " + launcherDirectory.getAbsolutePath() );
		File commandBoxHome = resolveCommandBoxHome( arguments, launcherDirectory );
		debug( "CommandBox home: " + commandBoxHome.getAbsolutePath() );
		System.setProperty( COMMANDBOX_HOME_PROPERTY, commandBoxHome.getAbsolutePath() );
		arguments = removeArgument( arguments, COMMANDBOX_HOME_PROPERTY );
		debug( "Arguments after bootstrap options: " + Arrays.toString( arguments ) );
		Path systemBoxJson = commandBoxHome.toPath().resolve( "cfml/box.json" );
		if ( Files.notExists( systemBoxJson ) ) {
			if ( !commandBoxHome.mkdirs() && !commandBoxHome.isDirectory() ) {
				throw new IOException( "Unable to create CommandBox home: " + commandBoxHome );
			}
			extractSystemModules( commandBoxHome.toPath() );
		}
		File boxLangHome = resolveBoxLangHome( launcherDirectory );
		debug( "BoxLang runtime home: " + boxLangHome.getAbsolutePath() );
		BoxLangInstallation boxLang = detectBoxLang( launcherDirectory );
		if ( boxLang == null ) {
			File boxLangInstallHome = resolveInstallerInstallHome( launcherDirectory );
			debug( "BoxLang was not detected; installing to: " + boxLangInstallHome.getAbsolutePath() );
			installBoxLang( boxLangInstallHome, boxLangHome );
			boxLang = new BoxLangInstallation( getExecutable( boxLangInstallHome ), "installer default" );
		}
		extractBxCliModule( boxLangHome.toPath(), boxLang.getExecutable() );
		createBoxLauncher( boxLang.getExecutable() );
		launchBoxLang( boxLang.getExecutable(), boxLangHome, commandBoxHome, arguments, boxLang.getSource() );
	}

	/**
	 * Stops before BoxLang setup when the current JVM cannot run BoxLang.
	 */
	private static void verifyJavaVersion() {
		int javaVersion = getJavaMajorVersion();
		if ( javaVersion < MINIMUM_JAVA_VERSION ) {
			System.err.println( "CommandBox requires Java " + MINIMUM_JAVA_VERSION + " or newer." );
			System.err.println( "Current Java version: " + System.getProperty( "java.version", "Unknown" ) );
			System.err.println( "Current Java home: " + System.getProperty( "java.home", "Unknown" ) );
			System.err.println( "Install Java " + MINIMUM_JAVA_VERSION + " or newer and try again." );
			System.exit( 1 );
		}
	}

	/**
	 * Parses Java 8 and modern Java version strings into a feature version.
	 *
	 * @return Java feature version, or zero when it cannot be parsed.
	 */
	private static int getJavaMajorVersion() {
		String version = System.getProperty( "java.version", "" );
		try {
			if ( version.startsWith( "1." ) ) {
				return Integer.parseInt( version.substring( 2, 3 ) );
			}
			int end = 0;
			while ( end < version.length() && Character.isDigit( version.charAt( end ) ) ) {
				end++;
			}
			return end == 0 ? 0 : Integer.parseInt( version.substring( 0, end ) );
		} catch ( NumberFormatException exception ) {
			return 0;
		}
	}

	/**
	 * Applies semicolon-delimited JVM properties supplied through BOX_JAVA_PROPS.
	 */
	private static void applyJavaProperties() {
		String javaProperties = System.getenv( "BOX_JAVA_PROPS" );
		debug( "BOX_JAVA_PROPS: " + ( javaProperties == null ? "<not set>" : javaProperties ) );
		if ( javaProperties == null || javaProperties.trim().isEmpty() ) {
			return;
		}
		for ( String property : javaProperties.split( ";" ) ) {
			int separator = property.indexOf( '=' );
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
		String commandLineHome = findArgumentValue( arguments, COMMANDBOX_HOME_PROPERTY );
		debug( "CommandBox home command-line value: " + commandLineHome );
		if ( commandLineHome != null ) {
			return resolveHome( commandLineHome, launcherDirectory );
		}

		Properties adjacentProperties = loadAdjacentProperties( launcherDirectory );
		debug( "Adjacent properties: " + adjacentProperties );
		String propertiesHome = getPropertyIgnoreCase( adjacentProperties, "cli.home" );
		if ( propertiesHome == null ) {
			propertiesHome = getPropertyIgnoreCase( adjacentProperties, COMMANDBOX_HOME_PROPERTY );
		}
		if ( propertiesHome != null ) {
			return resolveHome( propertiesHome, launcherDirectory );
		}

		String environmentHome = getEnvironmentIgnoreCase( COMMANDBOX_HOME_PROPERTY );
		debug( "CommandBox home environment value: " + environmentHome );
		if ( environmentHome != null ) {
			return resolveHome( environmentHome, launcherDirectory );
		}
		String systemHome = getPropertyIgnoreCase( System.getProperties(), COMMANDBOX_HOME_PROPERTY );
		debug( "CommandBox home JVM property value: " + systemHome );
		if ( systemHome != null ) {
			return resolveHome( systemHome, launcherDirectory );
		}
		String defaultHome = System.getProperty( "user.home" );
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
		Properties properties = new Properties();
		File commandBoxProperties = new File( launcherDirectory, "commandbox.properties" );
		File cliProperties = new File( launcherDirectory, "cli.properties" );
		File propertiesFile = commandBoxProperties.isFile() ? commandBoxProperties : cliProperties;
		debug( "Checking properties file: " + commandBoxProperties.getAbsolutePath() );
		debug( "Checking properties file: " + cliProperties.getAbsolutePath() );
		if ( propertiesFile.isFile() ) {
			debug( "Loading properties file: " + propertiesFile.getAbsolutePath() );
			try ( FileInputStream input = new FileInputStream( propertiesFile ) ) {
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
		String environmentHome = getEnvironmentIgnoreCase( BOXLANG_INSTALL_HOME_ENVIRONMENT );
		if ( environmentHome != null ) {
			return new File( environmentHome );
		}
		Properties adjacentProperties = loadAdjacentProperties( launcherDirectory );
		String configuredHome = getPropertyIgnoreCase( adjacentProperties, BOXLANG_INSTALL_HOME_PROPERTY );
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
		String bvmHome = getEnvironmentIgnoreCase( BVM_HOME_ENVIRONMENT );
		String installHome = getEnvironmentIgnoreCase( BOXLANG_INSTALL_HOME_ENVIRONMENT );
		String boxLangHome = getEnvironmentIgnoreCase( BOXLANG_HOME_ENVIRONMENT );
		String configuredHome = getPropertyIgnoreCase( System.getProperties(), BOXLANG_HOME_PROPERTY );
		String configuredInstallHome = getPropertyIgnoreCase( System.getProperties(), BOXLANG_INSTALL_HOME_PROPERTY );
		Properties adjacentProperties = loadAdjacentProperties( launcherDirectory );
		String adjacentInstallHome = getPropertyIgnoreCase( adjacentProperties, BOXLANG_INSTALL_HOME_PROPERTY );
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
			return findInstallation( new File( boxLangHome, "../bin" ), "BOXLANG_HOME" );
		}
		// Check the configured JVM home because it is an explicit local installation override.
		if ( configuredHome != null ) {
			File executableDirectory = isWindows() ? new File( configuredHome, "../bin" ) : new File( configuredHome, "bin" );
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
		BoxLangInstallation pathInstallation = findOnPath();
		debug( pathInstallation == null ? "BoxLang was not found on PATH." : "BoxLang found on PATH: " + pathInstallation.getExecutable() );
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
		File executable = new File( binDirectory, isWindows() ? "boxlang.bat" : "boxlang" );
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
		List<String> command = isWindows() ? Arrays.asList( "where.exe", "boxlang" ) : Arrays.asList( "sh", "-c", "command -v boxlang" );
		debug( "Checking PATH with: " + command );
		Process process = new ProcessBuilder( command ).redirectErrorStream( true ).start();
		String output = new String( readAllBytes( process.getInputStream() ), StandardCharsets.UTF_8 ).trim();
		int exitCode = process.waitFor();
		debug( "PATH lookup exit code: " + exitCode + ", output: " + output );
		if ( exitCode != 0 || output.isEmpty() ) {
			return null;
		}
		File executable = new File( output.split( "\\R" )[ 0 ].trim() );
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
		Properties adjacentProperties = loadAdjacentProperties( launcherDirectory );
		String configuredHome = getPropertyIgnoreCase( adjacentProperties, BOXLANG_HOME_PROPERTY );
		debug( "boxlang.home property: " + configuredHome );
		if ( configuredHome != null ) {
			return resolveHome( configuredHome, launcherDirectory );
		}
		String environmentHome = getEnvironmentIgnoreCase( BOXLANG_HOME_ENVIRONMENT );
		debug( "BOXLANG_HOME: " + environmentHome );
		if ( environmentHome != null ) {
			return new File( environmentHome );
		}
		String systemHome = getPropertyIgnoreCase( System.getProperties(), BOXLANG_HOME_PROPERTY );
		debug( "boxlang.home JVM property: " + systemHome );
		if ( systemHome != null ) {
			return resolveHome( systemHome, launcherDirectory );
		}
		String userHome = System.getProperty( "user.home" );
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
		File home = new File( value );
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
		String prefix = "-" + name.toLowerCase( Locale.ROOT ) + "=";
		for ( String argument : arguments ) {
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
		String prefix = "-" + name.toLowerCase( Locale.ROOT ) + "=";
		List<String> remainingArguments = new ArrayList<String>();
		for ( String argument : arguments ) {
			if ( !argument.toLowerCase( Locale.ROOT ).startsWith( prefix ) ) {
				remainingArguments.add( argument );
			}
		}
		return remainingArguments.toArray( new String[ remainingArguments.size() ] );
	}

	/**
	 * Reads an environment variable without regard to case.
	 *
	 * @param name Environment variable name.
	 * @return Environment value, or null when absent.
	 */
	private static String getEnvironmentIgnoreCase( String name ) {
		for ( Map.Entry<String, String> entry : System.getenv().entrySet() ) {
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
		for ( Map.Entry<?, ?> entry : properties.entrySet() ) {
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
		String resourceName = isWindows() ? "install-boxlang.ps1" : "install-boxlang.sh";
		Path temporaryDirectory = Files.createTempDirectory( "commandbox-installer-" );
		Path installerDirectory = temporaryDirectory.resolve( "installer" );
		Path installerPath = installerDirectory.resolve( resourceName );
		try {
			debug( "Installer archive resource: " + INSTALLER_ARCHIVE );
			debug( "Installer temporary directory: " + temporaryDirectory );
			extractInstallerArchive( installerDirectory );
			if ( Files.notExists( installerPath ) ) {
				throw new IOException( "Missing installer script in archive: " + resourceName );
			}
			Path boxLangJar = extractOptionalResource( BOXLANG_JAR, temporaryDirectory );
			Path miniServerJar = extractOptionalResource( MINISERVER_JAR, temporaryDirectory );
			List<String> command = new ArrayList<String>();
			if ( isWindows() ) {
				command.addAll( Arrays.asList( "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", installerPath.toString() ) );
			} else {
				command.addAll( Arrays.asList( "bash", installerPath.toString() ) );
			}
			if ( boxLangJar != null && miniServerJar != null ) {
				command.addAll( Arrays.asList(
					"--force", "--non-interactive", "--without-jre", "--without-commandbox",
					"--boxlang-path", boxLangJar.toString(),
					"--miniserver-path", miniServerJar.toString(),
					"--installer-scripts-path", installerDirectory.toString()
				) );
				debug( "Using bundled BoxLang runtime artifacts for offline installation." );
			} else {
				command.addAll( Arrays.asList(
					getBoxLangVersion(), "--non-interactive", "--without-jre", "--without-commandbox",
					"--installer-scripts-path", installerDirectory.toString()
				) );
			}
			ProcessBuilder processBuilder = new ProcessBuilder( command ).inheritIO();
			debug( "Installer command: " + command );
			debug( "Installer BOXLANG_INSTALL_HOME: " + boxLangInstallHome.getAbsolutePath() );
			debug( "Installer BOXLANG_HOME: " + boxLangHome.getAbsolutePath() );
			processBuilder.environment().put( "BOXLANG_INSTALL_HOME", boxLangInstallHome.getAbsolutePath() );
			processBuilder.environment().put( "BOXLANG_HOME", boxLangHome.getAbsolutePath() );
			int exitCode = processBuilder.start().waitFor();
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
		try ( InputStream input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( BOXLANG_VERSION ) ) {
			if ( input == null ) {
				return "latest";
			}
			return new String( readAllBytes( input ), StandardCharsets.UTF_8 ).trim();
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
		try ( InputStream input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( resourceName ) ) {
			if ( input == null ) {
				debug( "Optional installer resource was not bundled: " + resourceName );
				return null;
			}
			Path destination = destinationDirectory.resolve( resourceName );
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
		Path moduleDir = boxLangHome.resolve( "modules/bx-cli" );
		try ( InputStream input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( "bx-cli.zip" ) ) {
			if ( input == null ) {
				installBxCliModule( boxLangHome, boxLangExecutable );
				return;
			}
			try ( ZipInputStream zip = new ZipInputStream( input ) ) {
				ZipEntry entry;
				while ( ( entry = zip.getNextEntry() ) != null ) {
					if ( entry.isDirectory() ) {
						continue;
					}
					Path destination = moduleDir.resolve( entry.getName() ).normalize();
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
		Path installHome = boxLangExecutable.toPath().toRealPath().getParent().getParent();
		Path scriptDirectory = isWindows() ? installHome.resolve( "bin" ) : installHome.resolve( "scripts" );
		Path script = scriptDirectory.resolve( isWindows() ? "install-bx-module.ps1" : "install-bx-module.sh" );
		if ( Files.notExists( script ) ) {
			throw new IOException( "BoxLang module installer was not installed: " + script );
		}
		List<String> command = isWindows()
			? Arrays.asList( "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script.toString(), "bx-cli" )
			: Arrays.asList( "sh", script.toString(), "bx-cli" );
		ProcessBuilder processBuilder = new ProcessBuilder( command ).inheritIO();
		processBuilder.environment().put( "BOXLANG_HOME", boxLangHome.toString() );
		processBuilder.environment().put( "BOXLANG_INSTALL_HOME", installHome.toString() );
		int exitCode = processBuilder.start().waitFor();
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
		Path boxLangPath = boxLangExecutable.toPath().toRealPath();
		Path launcher = boxLangPath.getParent().resolve( isWindows() ? "box.bat" : "box" );
		String executablePath = boxLangPath.toString();
		String contents = isWindows()
			? "@echo off\r\n\"" + executablePath + "\" cli %*\r\n"
			: "#!/bin/sh\nexec \"" + executablePath + "\" cli \"$@\"\n";
		Files.write( launcher, contents.getBytes( StandardCharsets.UTF_8 ) );
		if ( !isWindows() && !launcher.toFile().setExecutable( true, false ) ) {
			throw new IOException( "Unable to make CommandBox launcher executable: " + launcher );
		}
		if ( isWindows() ) {
			debug( "CommandBox launcher created at: " + launcher );
			return;
		}
		BoxLangInstallation pathInstallation = findOnPath();
		if ( pathInstallation != null ) {
			Path systemLauncher = pathInstallation.getExecutable().toPath().getParent().resolve( "box" );
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
		Path cfmlDirectory = commandBoxHome.resolve( "cfml" );
		try ( InputStream input = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( SYSTEM_MODULES_ARCHIVE ) ) {
			if ( input == null ) {
				debug( "Optional system modules archive was not bundled: " + SYSTEM_MODULES_ARCHIVE );
				return;
			}
			try ( ZipInputStream zip = new ZipInputStream( input ) ) {
				ZipEntry entry;
				while ( ( entry = zip.getNextEntry() ) != null ) {
					Path destination = cfmlDirectory.resolve( entry.getName() ).normalize();
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
		List<String> command = new ArrayList<String>();
		if ( isWindows() ) {
			command.addAll( Arrays.asList( "cmd", "/c", executable.getAbsolutePath(), "cli" ) );
		} else {
			command.addAll( Arrays.asList( executable.getAbsolutePath(), "cli" ) );
		}
		command.addAll( Arrays.asList( arguments ) );
		ProcessBuilder processBuilder = new ProcessBuilder( command ).inheritIO();
		debug( "BoxLang command: " + command );
		debug( "BoxLang BOXLANG_HOME: " + boxLangHome.getAbsolutePath() );
		debug( "BoxLang CommandBox_home: " + commandBoxHome.getAbsolutePath() );
		processBuilder.environment().put( "BOXLANG_HOME", boxLangHome.getAbsolutePath() );
		processBuilder.environment().put( COMMANDBOX_HOME_PROPERTY, commandBoxHome.getAbsolutePath() );
		int exitCode = processBuilder.start().waitFor();
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
		InputStream resource = CommandBoxCLIMain.class.getClassLoader().getResourceAsStream( INSTALLER_ARCHIVE );
		if ( resource == null ) {
			throw new IOException( "Missing launcher resource: " + INSTALLER_ARCHIVE );
		}
		try ( InputStream input = resource ) {
			Files.createDirectories( destinationDirectory );
			try ( ZipInputStream zip = new ZipInputStream( input ) ) {
				ZipEntry entry;
				while ( ( entry = zip.getNextEntry() ) != null ) {
					debug( "Extracting installer entry: " + entry.getName() );
					Path destination = destinationDirectory.resolve( entry.getName() ).normalize();
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
		for ( String argument : arguments ) {
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
		List<String> remainingArguments = new ArrayList<String>();
		for ( String argument : arguments ) {
			if ( !argument.equalsIgnoreCase( "-clidebug" ) ) {
				remainingArguments.add( argument );
			}
		}
		return remainingArguments.toArray( new String[ remainingArguments.size() ] );
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
		try ( Stream<Path> paths = Files.walk( directory ) ) {
			paths.sorted( Comparator.reverseOrder() ).forEach( path -> {
				try {
					Files.deleteIfExists( path );
				} catch ( IOException exception ) {
					throw new RuntimeException( exception );
				}
			} );
		}
	}

	/**
	 * Reads all bytes from an input stream on Java 8.
	 *
	 * @param input Input stream to read.
	 * @return Stream bytes.
	 * @throws IOException If the stream cannot be read.
	 */
	private static byte[] readAllBytes( InputStream input ) throws IOException {
		ByteArrayOutputStream output = new ByteArrayOutputStream();
		byte[] buffer = new byte[ 8192 ];
		int length;
		while ( ( length = input.read( buffer ) ) != -1 ) {
			output.write( buffer, 0, length );
		}
		return output.toByteArray();
	}

	/**
	 * Describes a detected BoxLang executable and how it was found.
	 */
	private static final class BoxLangInstallation {

		private final File executable;
		private final String source;

		private BoxLangInstallation( File executable, String source ) {
			this.executable = executable;
			this.source = source;
		}

		private File getExecutable() {
			return executable;
		}

		private String getSource() {
			return source;
		}

	}

}
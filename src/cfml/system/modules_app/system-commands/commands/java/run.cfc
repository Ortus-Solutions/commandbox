/**
 * Runs the compiled output of the project using the conventions in box.json.
 *
 * {code:bash}
 * java run
 * java run mainClass=example.App
 * java run jarFile=dist/my-app.jar
 * java run javaVersion=openjdk17
 * java run :1=arg1 :2=arg2
 * {code}
 *
 * Java program arguments can be supplied two ways:
 * - As a struct via dynamic params: :1=arg1 :2=arg2 (ordered by numeric key)
 * - As a space-delimited string via the args param: args="arg1 arg2"
 *
 * The Java version is treated as a Java install ID just like the
 * server java install command. If none is provided, the version the CLI is
 * running is used. If box.json declares a minimum Java version, a compatible
 * install is found or downloaded just like the compile DSL does.
 **/
component extends="commandbox.system.BaseCommand" {

	property name="packageService" inject="PackageService";
	property name="javaService" inject="JavaService";
	property name="fileSystemUtil" inject="FileSystem";

	/**
	 * @mainClass The class to execute. Overrides box.json java.jarOptions.mainClass.
	 * @jarFile The JAR file to run. Overrides box.json java.jarName.
	 * @jarFile.optionsFileComplete true
	 * @libsDirectory Libs directory(ies) to add to the classpath. Comma-delimited, searched recursively for JARs. Overrides box.json java.libsDir.
	 * @libsDirectory.optionsDirectoryComplete true
	 * @classesDirectory Compiled classes directory to add to the classpath. Overrides box.json java.classes.
	 * @classesDirectory.optionsDirectoryComplete true
	 * @javaVersion Java install ID to use, like openjdk17. Defaults to the CLI's Java or a version matching box.json java.minJVM.
	 * @args Java program arguments as a space-delimited string, or a struct of :N=value dynamic params.
	 * @verbose Show verbose output
	 */
	function run(
		string mainClass="",
		string jarFile="",
		string libsDirectory="",
		string classesDirectory="",
		string javaVersion="",
		any args,
		boolean verbose=false
	) {
		var boxJSON = getBoxJSON();

		// Resolve the Java version to use (arg -> box.json -> CLI default)
		var javaBin = resolveJavaBin( arguments.javaVersion, boxJSON, arguments.verbose );

		// Split the args into JVM args and program args. JVM args are the ones
		// that look like JVM flags (leading single hyphen, e.g. -Xmx512m,
		// -Dfoo=bar); everything else is forwarded to main().
		var argsSplit = splitJvmArgs( resolveProgramArgs( arguments.args ) );
		var jvmArgs = argsSplit.jvmArgs;
		var programArgs = argsSplit.programArgs;

		// Resolve the run target. jar=true (or an explicit jarFile) means the
		// JAR is always the target - never fall back to class files.
		var useJar = arguments.jarFile.len() || ( boxJSON.java.jar ?: false );
		var runJarFile = arguments.jarFile.len() ? arguments.jarFile : ( boxJSON.java.jarName ?: "" );

		// When box.json says to make a jar but no name is given, derive it from
		// the package the same way the compile DSL does: <slug>-<version>.jar
		// in the libs directory. A bare jarName (no path separator) also gets
		// the libs directory prepended.
		if( useJar && runJarFile.len() ) {
			// A bare filename (no path separator) gets the libs dir prepended
			if( !reFind( "[\\/]", runJarFile ) ) {
				runJarFile = resolvePath( boxJSON.java.libsDir ?: "libs" ) & "/" & runJarFile;
			}
		} else if( useJar ) {
			var libsDirPath = resolvePath( boxJSON.java.libsDir ?: "libs" );
			var derivedName = getJarNameFromPackage();
			if( derivedName.len() ) {
				runJarFile = libsDirPath & "/" & derivedName;
			} else {
				error( "Cannot determine the JAR name. Set java.jarName in box.json or pass jarFile=." );
			}
		}

		var javaExecutable = javaBin & ( fileSystemUtil.isWindows() ? "java.exe" : "java" );

		// Run from the JAR when that's the configured target
		if( useJar ) {
			var jarPath = resolvePath( runJarFile );
			if( !fileExists( jarPath ) ) {
				error( "JAR file not found: [#jarPath#]. Run `java compile` to build the project first." );
			}
			var cmd = '"#javaExecutable#"#formatArgs( jvmArgs )# -jar "#jarPath#"#formatArgs( programArgs )#';
			return runJavaProcess( cmd, verbose );
		}

		// Otherwise run the main class from the classpath
		var mainClass = arguments.mainClass.len() ? arguments.mainClass : ( boxJSON.java.jarOptions.mainClass ?: "" );
		if( !mainClass.len() ) {
			error( "No main class found. Pass mainClass= or set java.jarOptions.mainClass in box.json." );
		}

		var classesDir = arguments.classesDirectory.len() ? arguments.classesDirectory : ( boxJSON.java.classes ?: "" );
		var classesDirPath = classesDir.len() ? resolvePath( classesDir ) : "";
		if( !classesDirPath.len() || !directoryExists( classesDirPath ) ) {
			error( "Compiled classes directory not found: [#classesDir#]. Run `java compile` to build the project first." );
		}
		// Nothing was compiled if the classes directory has no class files
		if( !directoryList( classesDirPath, true, "name", "*.class" ).len() ) {
			error( "No compiled classes found in [#classesDir#]. Run `java compile` to build the project first." );
		}

		var classPath = buildClassPath( arguments.classesDirectory, arguments.libsDirectory, boxJSON );
		var cmd = '"#javaExecutable#"#formatArgs( jvmArgs )# -cp "#classPath#" #mainClass##formatArgs( programArgs )#';
		return runJavaProcess( cmd, verbose );
	}

	/**
	 * Reads the project box.json if present, defaulting to an empty struct.
	 */
	private struct function getBoxJSON() {
		var directory = getCWD();
		if( packageService.isPackage( directory ) ) {
			return packageService.readPackageDescriptor( directory );
		}
		return {};
	}

	/**
	 * Resolves the Java bin directory to use.
	 *
	 * @javaVersionArg Java install ID passed as a command arg, e.g. openjdk17.
	 * @boxJSON The project box.json.
	 * @verbose Pass through to the Java install so downloads show progress.
	 */
	private string function resolveJavaBin( required string javaVersionArg, required struct boxJSON, boolean verbose=false ) {
		var javaEndpoint = wirebox.getInstance( "endpointService" ).getEndpoint( "java" );

		// Explicit javaVersion arg wins
		if( arguments.javaVersionArg.len() ) {
			return javaService.getJavaInstallPath( arguments.javaVersionArg, arguments.verbose ) & "/bin/";
		}

		// box.json java.javaVersion (explicit install ID) next
		var configVersion = boxJSON.java.javaVersion ?: "";
		if( len( configVersion ) ) {
			return javaService.getJavaInstallPath( configVersion, arguments.verbose ) & "/bin/";
		}

		// minJVM in box.json: find an installed Java >= the minimum
		var minJVM = val( boxJSON.java.minJVM ?: 0 );
		if( minJVM > 0 ) {
			var installedJREs = javaService.listJavaInstalls();
			for( var installID in installedJREs ) {
				var javaInstall = installedJREs[ installID ];
				if( !javaInstall.isInstalled ) {
					continue;
				}
				var javaDetails = javaEndpoint.parseDetails( javaInstall.packageVersion );
				if( javaDetails.type != "jdk" && javaDetails.type != "jre" ) {
					continue;
				}
				var installedVersion = val( reReplaceNoCase( javaDetails.version, "openjdk", "" ) );
				if( installedVersion >= minJVM ) {
					return javaInstall.directory.listAppend( installID, "/" ) & "/bin/";
				}
			}
			// Fall back to downloading the minimum version
			return javaService.getJavaInstallPath( "openjdk#minJVM#", arguments.verbose ) & "/bin/";
		}

		// Default: use the Java the CLI itself is running
		return getDirectoryFromPath( fileSystemUtil.getJREExecutable() );
	}

	/**
	 * Derives the default JAR filename from the package slug and version,
	 * matching the compile DSL: <slug>-<version>.jar.
	 */
	private string function getJarNameFromPackage() {
		var directory = getCWD();
		if( !packageService.isPackage( directory ) ) {
			return "";
		}
		var boxJSON = packageService.readPackageDescriptor( directory );
		if( !len( boxJSON.slug ?: "" ) ) {
			return "";
		}
		var jarName = boxJSON.slug;
		if( len( boxJSON.version ?: "" ) ) {
			jarName &= "-" & boxJSON.version;
		}
		return jarName & ".jar";
	}

	/**
	 * Resolves the Java program arguments from the `args` param.
	 *
	 * Accepts either a struct of `:N=value` dynamic params (sorted by numeric
	 * key) or a space-delimited string.
	 */
	private array function resolveProgramArgs( required any args ) {
		if( isNull( arguments.args ) || ( isSimpleValue( arguments.args ) && !len( arguments.args ) ) ) {
			return [];
		}
		if( isStruct( arguments.args ) ) {
			var keys = arguments.args.keyArray();
			keys.sort( "textnocase", "asc" );
			return keys.map( function( k ) {
				return args[ k ];
			} );
		}
		// Simple string: split on spaces
		return listToArray( arguments.args, " " );
	}

	/**
	 * Splits resolved args into JVM args and program args.
	 *
	 * JVM args are the ones that look like JVM flags - a leading single hyphen
	 * such as -Xmx512m or -Dfoo=bar. Everything else is a program arg. The
	 * split is an implementation detail of building the java command line.
	 */
	private struct function splitJvmArgs( required array allArgs ) {
		var jvmArgs = [];
		var programArgs = [];
		for( var arg in arguments.allArgs ) {
			if( left( arg, 1 ) == "-" && left( arg, 2 ) != "--" ) {
				jvmArgs.append( arg );
			} else {
				programArgs.append( arg );
			}
		}
		return { "jvmArgs" : jvmArgs, "programArgs" : programArgs };
	}

	/**
	 * Builds the classpath from the classes directory, libs directory(ies), and
	 * box.json defaults.
	 */
	private string function buildClassPath( required string classesArg, required string libsArg, required struct boxJSON ) {
		var entries = [];

		var classesDir = arguments.classesArg.len() ? arguments.classesArg : ( boxJSON.java.classes ?: "" );
		if( len( classesDir ) && directoryExists( resolvePath( classesDir ) ) ) {
			// Strip any trailing slash so it can't escape the surrounding quotes
			entries.append( reReplace( resolvePath( classesDir ), "[\\/]+$", "" ) );
		}

		var libsList = arguments.libsArg.len() ? arguments.libsArg : ( boxJSON.java.libsDir ?: "" );
		for( var libDir in listToArray( libsList, "," ) ) {
			var libDirPath = resolvePath( trim( libDir ) );
			if( !directoryExists( libDirPath ) ) {
				continue;
			}
			// Recursively find all JARs, like the maven install does
			var jars = directoryList( libDirPath, true, "path", "*.jar" );
			for( var jar in jars ) {
				entries.append( jar );
			}
		}

		return entries.toList( fileSystemUtil.isWindows() ? ";" : ":" );
	}

	/**
	 * Formats the program args into a shell command string.
	 */
	private string function formatArgs( required array programArgs ) {
		if( !arguments.programArgs.len() ) {
			return "";
		}
		return " " & arguments.programArgs.map( function( arg ) {
			return '"#arguments.arg#"';
		} ).toList( " " );
	}

	/**
	 * Executes the Java process and propagates its exit code.
	 *
	 * Delegates to the run command through CommandDSL (same as the compile
	 * DSL's runCompileCommand) so output is streamed live (not captured) and
	 * console input is passed through, which is important for interactive
	 * Java programs.
	 *
	 * On Windows, the whole command is wrapped in an extra set of quotes so
	 * cmd /c handles a leading quoted path with spaces (e.g. "C:\Program
	 * Files\...\java.exe"). This matches the compile DSL's nativeRunCommand(),
	 * which always appends the trailing quote regardless of the command's
	 * final argument.
	 */
	private function runJavaProcess( required string cmd, boolean verbose=false ) {
		if( arguments.verbose ) {
			print.line( "Running: #cmd#" ).toConsole();
		}
		var wrappedCmd = fileSystemUtil.isWindows()
			? '"' & arguments.cmd & '"'
			: arguments.cmd;
		wirebox
			.getInstance( name="CommandDSL", initArguments={ "name" : "run" } )
			.params( wrappedCmd )
			.run();
	}

}

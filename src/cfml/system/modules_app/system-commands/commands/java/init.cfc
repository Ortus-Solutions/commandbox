/**
 * Adds a java compile configuration to the project's box.json and creates the
 * convention folders for the Compile DSL.
 *
 * {code:bash}
 * java init
 * java init sourcePath=src/custom/java classesDirectory=build/classes libsDirectory=dist
 * java init ide=vscode
 * {code}
 *
 * All convention folder paths can be overridden. Folders that do not exist are
 * created. When the source folder is newly created, a sample
 * example/Example.java is stubbed in that prints "Hello, World!" along with a
 * matching example/ExampleTest.java.
 *
 * A test framework is added to `devDependencies` and its install path to
 * `installPaths`, unless the project already names a junit or testng artifact
 * there. Both are merged, never replaced, so re-running `java init` does not
 * drop dependencies a project already has.
 **/
component extends="commandbox.system.BaseCommand" {

	property name="packageService" inject="PackageService";

	/**
	 * @sourcePath Java source directory
	 * @classesDirectory Compiled class output directory
	 * @libsDirectory JAR output directory
	 * @resourcesDirectory Resource directory to include in a JAR
	 * @javaDocsDirectory Javadoc output directory
	 * @testSourcePath Test source directory. Defaults to the main source path with `main` swapped for `test`.
	 * @testClassesDirectory Compiled test class output directory. Defaults to the main classes path with `main` swapped for `test`.
	 * @testResourcesDirectory Test resource directory
	 * @ide Also write editor metadata for this editor: vscode, eclipse, intellij. Comma-delimited for several.
	 * @ide.options vscode,eclipse,intellij
	 * @force Overwrite the java config when box.json already has one
	 */
	function run(
		string sourcePath="src/main/java",
		string classesDirectory="build/classes/java/main",
		string libsDirectory="build/libs",
		string resourcesDirectory="src/main/resources",
		string javaDocsDirectory="build/docs/javadoc",
		string testSourcePath="",
		string testClassesDirectory="",
		string testResourcesDirectory="",
		string ide="",
		boolean force=false
	) {
		var directory = getCWD();
		if( !packageService.isPackage( directory ) ) {
			print.line( "No box.json found. Running `package init` first..." ).toConsole();
			command( "package init" ).run();
		}

		// The test conventions are derived from the main ones the same way the
		// compile DSL derives them, so an override of sourcePath or
		// classesDirectory carries over unless it is given explicitly.
		var testSource = len( arguments.testSourcePath )
			? arguments.testSourcePath
			: swapMainSegment( arguments.sourcePath, "src/test/java" );
		var testClasses = len( arguments.testClassesDirectory )
			? arguments.testClassesDirectory
			: swapMainSegment( arguments.classesDirectory, "build/classes/java/test" );
		var testResources = len( arguments.testResourcesDirectory )
			? arguments.testResourcesDirectory
			: swapMainSegment( arguments.resourcesDirectory, "src/test/resources" );

		var boxJSON = packageService.readPackageDescriptorRaw( directory );
		if( boxJSON.keyExists( "java" ) && !arguments.force ) {
			print.line( "box.json already has a `java` configuration. Use --force to overwrite it." ).toConsole();
			// An `ide` request is still worth honoring: the project is already
			// initialized, it just wants its editor metadata (re)written.
			runIdeInit( arguments.ide );
			return;
		}

		var javaConfig = {
			"sourcePath"             : arguments.sourcePath,
			"classesDirectory"       : arguments.classesDirectory,
			"libsDirectory"          : arguments.libsDirectory,
			"resourcesDirectory"     : arguments.resourcesDirectory,
			"javaDocsDirectory"      : arguments.javaDocsDirectory,
			"testSourcePath"         : testSource,
			"testClassesDirectory"   : testClasses,
			"testResourcesDirectory" : testResources,
			"classPath"              : [],
			"testClassPath"          : [],
			"jar"                    : false,
			"jarFile"                : "",
			"fatJar"                 : false,
			"fatJarFile"             : "",
			"fatJarPaths"            : [],
			"compileOptions"         : {},
			"jarOptions"             : {},
			"fatJarOptions"          : {
				"mergeServiceDescriptors" : true,
				"excludeSignatures"       : true,
				"duplicatePolicy"         : "last",
				"mergeLog4jPluginCaches"  : false
			},
			"manifest"               : {},
			"runArgs"                : [],
			"javaDocs"               : false,
			"verbose"                : false
		};
		// The source folder determines whether we stub a sample class.
		var sourceExisted = directoryExists( resolvePath( arguments.sourcePath ) );
		var testSourceExisted = directoryExists( resolvePath( testSource ) );
		// When we create the source folder, point the JAR entry point at the
		// stubbed example class and enable JAR creation so a bare
		// `java compile` produces a runnable JAR.
		if( !sourceExisted ) {
			javaConfig.jar = true;
			javaConfig.jarOptions[ "mainClass" ] = "example.Example";
		}
		if( arguments.force && isStruct( boxJSON.java ?: {} ) ) {
			structAppend( boxJSON.java, javaConfig, true );
		} else {
			boxJSON["java"] = javaConfig;
		}

		// A scaffolded test needs a framework. Merge the dev dependencies and their
		// install paths so a project that already has its own choices keeps them.
		var addedDevDependencies = ensureTestFramework( boxJSON );

		packageService.writePackageDescriptor( boxJSON, directory );

		// Create the convention folders
		var conventionFolders = {
			"sourcePath"             : arguments.sourcePath,
			"classesDirectory"       : arguments.classesDirectory,
			"libsDirectory"          : arguments.libsDirectory,
			"resourcesDirectory"     : arguments.resourcesDirectory,
			"javaDocsDirectory"      : arguments.javaDocsDirectory,
			"testSourcePath"         : testSource,
			"testClassesDirectory"   : testClasses,
			"testResourcesDirectory" : testResources
		};
		for( var folder in conventionFolders ) {
			var folderPath = resolvePath( conventionFolders[ folder ] );
			if( !directoryExists( folderPath ) ) {
				directoryCreate( folderPath, true );
				print.cyanLine( "- Created folder: #conventionFolders[ folder ]#" ).toConsole();
			}
		}

		// Stub a sample source file when the source folder was just created. The
		// matching test is stubbed at the same time so the class and its test
		// always appear together, and init never drops a file into an existing tree.
		if( !sourceExisted ) {
			writeStub( arguments.sourcePath, "example/Example.java", "Example.java.txt", "sample source" );

			if( !testSourceExisted ) {
				writeStub( testSource, "example/ExampleTest.java", "ExampleTest.java.txt", "sample test" );
			}
		}

		if( addedDevDependencies.len() ) {
			print.cyanLine( "- Added dev dependencies to box.json: #addedDevDependencies.toList( ", " )#" ).toConsole();
		}

		print.greenLine( "Java configuration added to box.json. Run `java compile` to build with these conventions, or `java test` to run the tests." ).toConsole();

		// Optionally finish the job: write the editor metadata too, so a scaffolded
		// project opens with its sources and dependencies already wired up.
		runIdeInit( arguments.ide );
	}

	/**
	 * Runs `java ide-init` for the requested editors, when any were requested.
	 *
	 * @ide Comma-delimited editor ids, or an empty string.
	 * @returns Nothing.
	 */
	private function runIdeInit( required string ide ) {
		if( !len( trim( arguments.ide ) ) ) {
			return;
		}

		command( "java ide-init" )
			.params( ide = arguments.ide )
			.run();
	}

	/**
	 * Merges the test framework into the project's devDependencies and installPaths.
	 *
	 * Nothing is added when the project already names a junit or testng artifact as
	 * a dev dependency, so a project that has chosen its own framework is left alone.
	 *
	 * @boxJSON The raw box.json descriptor to modify.
	 * @returns The list of dev dependencies that were added.
	 */
	private array function ensureTestFramework( required struct boxJSON ) {
		boxJSON[ "devDependencies" ] = boxJSON.devDependencies ?: {};
		var existingDevDependencies = boxJSON.devDependencies;

		for( var existing in existingDevDependencies ) {
			if( findNoCase( "junit", existing ) || findNoCase( "testng", existing ) ) {
				return [];
			}
		}

		// JUnit does the running, so all the scaffold needs is JUnit's console
		// launcher. The standalone JAR is a single self-contained artifact: it
		// bundles the platform, the launcher and the Jupiter engine, so there is
		// no compiled helper for CommandBox to ship or build.
		var testFramework = {
			"org.junit.platform:junit-platform-console-standalone" : "maven:org.junit.platform:junit-platform-console-standalone:1.12.2"
		};

		boxJSON[ "installPaths" ] = boxJSON.installPaths ?: {};
		// installPaths entries are resolved relative to the project root, so each one
		// points at the package folder the maven endpoint creates inside the dev
		// install directory. Recording it here is what lets uninstall find the package.
		var devInstallDirectory = boxJSON.maven.devInstallDirectory ?: "";
		if( !isSimpleValue( devInstallDirectory ) || !len( trim( devInstallDirectory ) ) ) {
			devInstallDirectory = "dist/test-dependencies";
		}
		devInstallDirectory = replace( trim( devInstallDirectory ), "\", "/", "all" );
		devInstallDirectory = reReplace( devInstallDirectory, "/+$", "" );

		var added = [];
		for( var dependencyName in testFramework ) {
			// Do not clobber a version the project already pinned.
			if( structKeyExists( existingDevDependencies, dependencyName ) ) {
				continue;
			}
			existingDevDependencies[ dependencyName ] = testFramework[ dependencyName ];
			// The package folder is `groupId-artifactId`, the same shape the maven
			// endpoint uses for a dependency's own directory.
			boxJSON.installPaths[ dependencyName ] = devInstallDirectory & "/" & replace( dependencyName, ":", "-" );
			added.append( dependencyName );
		}

		return added;
	}

	/**
	 * Writes a stub source file from its module template.
	 *
	 * @sourceDirectory The source root the stub lives under.
	 * @relativeFile The path of the stub relative to that root.
	 * @templateName The template file to read next to this command.
	 * @label The human-readable label used in the console output.
	 * @returns Nothing.
	 */
	private function writeStub(
		required string sourceDirectory,
		required string relativeFile,
		required string templateName,
		required string label
	) {
		var destination = resolvePath( arguments.sourceDirectory & "/" & arguments.relativeFile );
		directoryCreate( getDirectoryFromPath( destination ), true );
		// Read the stub template via the module mapping so it is easy to
		// modify without touching the command code.
		var template = fileRead( expandPath( "/system-commands/commands/java/#arguments.templateName#" ) );
		fileWrite( destination, template );
		print.cyanLine( "- Created #arguments.label#: #arguments.sourceDirectory#/#arguments.relativeFile#" ).toConsole();
	}

	/**
	 * Swaps the `main` path segment of a convention path for `test`, returning the
	 * supplied default when there is no `main` segment to swap.
	 *
	 * @path The main convention path.
	 * @defaultValue The value to use when no derivation is possible.
	 * @returns The derived test path.
	 */
	private string function swapMainSegment( required string path, required string defaultValue ) {
		var normalized = replace( arguments.path, "\", "/", "all" );
		var derived = reReplaceNoCase( normalized, "(^|/)main(/|$)", "\1test\2" );
		return derived == normalized ? arguments.defaultValue : derived;
	}

}

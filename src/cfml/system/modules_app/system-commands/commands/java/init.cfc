/**
 * Adds a java compile configuration to the project's box.json and creates the
 * convention folders for the Compile DSL.
 *
 * {code:bash}
 * java init
 * java init source=src/custom/java classes=build/classes libsDir=dist
 * {code}
 *
 * All convention folder paths can be overridden. Folders that do not exist are
 * created. When the source folder is newly created, a sample
 * example/Example.java is stubbed in that prints "Hello, World!".
 **/
component extends="commandbox.system.BaseCommand" {

	property name="packageService" inject="PackageService";

	/**
	 * @source Java source directory
	 * @classes Compiled class output directory
	 * @libsDir JAR output directory
	 * @resources Resource directory to include in a JAR
	 * @javaDocsDir Javadoc output directory
	 * @force Overwrite the java config when box.json already has one
	 */
	function run(
		string source="src/main/java",
		string classes="build/classes/java/main",
		string libsDir="build/libs",
		string resources="src/main/resources",
		string javaDocsDir="build/docs/javadoc",
		boolean force=false
	) {
		var directory = getCWD();
		if( !packageService.isPackage( directory ) ) {
			print.line( "No box.json found. Running `package init` first..." ).toConsole();
			command( "package init" ).run();
		}

		var boxJSON = packageService.readPackageDescriptorRaw( directory );
		if( boxJSON.keyExists( "java" ) && !arguments.force ) {
			print.line( "box.json already has a `java` configuration. Use --force to overwrite it." ).toConsole();
			return;
		}

		var javaConfig = {
			"source"         : arguments.source,
			"classes"        : arguments.classes,
			"libsDir"        : arguments.libsDir,
			"resources"      : arguments.resources,
			"javaDocsDir"    : arguments.javaDocsDir,
			"classPath"      : [],
			"jar"            : false,
			"jarName"        : "",
			"fatJar"         : false,
			"fatJarName"     : "",
			"fatJarJars"     : [],
			"compileOptions" : {},
			"jarOptions"     : {},
			"fatJarOptions"  : {
				"mergeServiceDescriptors" : true,
				"excludeSignatures"       : true,
				"duplicatePolicy"         : "last"
			},
			"manifest"       : {},
			"javaDocs"       : false,
			"verbose"        : false
		};
		// The source folder determines whether we stub a sample class.
		var sourceExisted = directoryExists( resolvePath( arguments.source ) );
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
		packageService.writePackageDescriptor( boxJSON, directory );

		// Create the convention folders
		var conventionFolders = {
			"source"      : arguments.source,
			"classes"     : arguments.classes,
			"libsDir"     : arguments.libsDir,
			"resources"   : arguments.resources,
			"javaDocsDir" : arguments.javaDocsDir
		};
		for( var folder in conventionFolders ) {
			var folderPath = resolvePath( conventionFolders[ folder ] );
			if( !directoryExists( folderPath ) ) {
				directoryCreate( folderPath, true );
				print.cyanLine( "- Created folder: #conventionFolders[ folder ]#" ).toConsole();
			}
		}

		// Stub a sample source file when the source folder was just created
		if( !sourceExisted ) {
			var exampleFile = resolvePath( arguments.source & "/example/Example.java" );
			directoryCreate( getDirectoryFromPath( exampleFile ), true );
			// Read the stub template via the module mapping so it is easy to
			// modify without touching the command code.
			var exampleSource = fileRead( expandPath( "/system-commands/commands/java/Example.java.txt" ) );
			fileWrite( exampleFile, exampleSource );
			print.cyanLine( "- Created sample source: #arguments.source#/example/Example.java" ).toConsole();
		}

		print.greenLine( "Java configuration added to box.json. Run `java compile` to build with these conventions." ).toConsole();
	}

}

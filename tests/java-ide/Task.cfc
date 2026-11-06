/**
 * Tests for `java ide-init`.
 *
 * Run from this directory with:
 *
 *     box task run
 *
 * Everything is generated under scratch/ (gitignored); nothing tracked is touched.
 * The dependency used to check resolution is built here with javac/jar, so no
 * network access is needed.
 */
component {

	/**
	 * Runs every check in this suite and reports the result once at the end.
	 */
	function run() {
		variables.repo = resolvePath( getDirectoryFromPath( getCurrentTemplatePath() ) & "../.." );
		variables.root = resolvePath( getDirectoryFromPath( getCurrentTemplatePath() ) & "scratch/" & createUUID() );
		// Load the checkout's implementation, not the installed CLI's copy.
		variables.system = componentPath( variables.repo & "/src/cfml/system" );
		wirebox.registerNewInstance( "JavaIDEDocuments", variables.system & ".util.JavaIDEDocuments" );
		wirebox.registerNewInstance( "JavaIDEModel", variables.system & ".services.JavaIDEModel" );
		wirebox.registerNewInstance( "JavaIDEService", variables.system & ".services.JavaIDEService" );
		variables.service = wirebox.getInstance( "JavaIDEService" );
		for( var id in [ "vscode", "eclipse", "intellij" ] ) {
			variables.service.register( id, emitterCfc( id ) );
		}
		variables.builder = wirebox.getInstance( "JavaIDEModel" );
		variables.command = wirebox.getInstance( variables.system & ".modules_app.system-commands.commands.java.ide-init" );

		try {
			fixture();
			model();
			detection();
			wroteFiles();
			resolvesDependencies();
			idempotent();
			preservesUserMetadata();
			dependencyChanges();
			reportsToTheUser();
			unknownEditorIsGraceful();
			defaultClassPaths();
			forcedEditor();
			defaultsToVSCodeWhenNoEditor();
		} finally {
			if( directoryExists( variables.root ) ) directoryDelete( variables.root, true );
		}
		print.greenLine( "java ide-init tests passed." ).toConsole();
	}

	/**
	 * Builds a throw-away project with a real JAR, so classpath resolution can be checked offline.
	 */
	private void function fixture() {
		for( var directory in [ "src/main/java", "src/generated", "src/main/resources", "libs/nested", ".vscode", "greeting" ] ) {
			directoryCreate( variables.root & "/" & directory, true );
		}
		// A real jar with a real class, so classpath resolution can be checked offline.
		fileWrite( variables.root & "/greeting/Greeting.java",
			'package dependency; public class Greeting { public static String hello() { return "hello"; } }' );
		var diagnostics = compileJava( variables.root & "/greeting/Greeting.java", variables.root & "/greeting-classes" );
		var classFiles = directoryList( variables.root & "/greeting-classes", true, "path", "*.class" );
		assertTrue( classFiles.len() == 1, "javac produced #classFiles.len()# class file(s). #diagnostics#" );
		var output = createObject( "java", "java.io.FileOutputStream" ).init( variables.root & "/libs/nested/greeting-1.0.jar" );
		var jar = createObject( "java", "java.util.jar.JarOutputStream" ).init( output );
		try {
			jar.putNextEntry( createObject( "java", "java.util.jar.JarEntry" ).init( "dependency/Greeting.class" ) );
			jar.write( fileReadBinary( classFiles[ 1 ] ) );
			jar.closeEntry();
		} finally {
			jar.close();
		}
		fileWrite( variables.root & "/src/main/java/App.java",
			"import dependency.Greeting; public class App { String message = Greeting.hello(); }" );
		variables.config = {
			"slug" : "ide-fixture",
			"java" : {
				"sourcePath" : [ "src/main/java", "src/generated" ], "classesDirectory" : "build/classes",
				"libsDirectory" : "build/libs", "resourcesDirectory" : "src/main/resources", "classPath" : [ "libs" ],
				"compileOptions" : { "release" : 17 }
			}
		};
		saveConfig();
		fileWrite( variables.root & "/.vscode/settings.json", '{"editor.tabSize":2,"files.exclude":{"build":true}}' );
	}

	/**
	 * Checks the editor-neutral model built from the fixture's box.json.
	 */
	private void function model() {
		var model = variables.builder.build( variables.root );
		assertEquals( "17", model.release, "release" );
		assertEquals( 2, model.sourceRoots.len(), "source roots" );
		assertEquals( "directory", model.classPath[ 1 ].kind, "classpath kind" );
		assertEquals( 1, model.dependencies.len(), "resolved dependencies" );
	}

	/**
	 * Checks that each editor is detected from its own metadata files.
	 */
	private void function detection() {
		assertEquals( "vscode", detect( variables.root ), "detects VS Code from .vscode" );
		directoryCreate( variables.root & "/.idea", true );
		fileWrite( variables.root & "/.idea/modules.xml", '<project version="4"/>' );
		assertEquals( "vscode,intellij", detect( variables.root ), "detects IntelliJ from .idea" );
		fileWrite( variables.root & "/.project", "<projectDescription/>" );
		assertEquals( "vscode,intellij,eclipse", detect( variables.root ), "detects Eclipse from .project" );
		directoryDelete( variables.root & "/.idea", true );
		fileDelete( variables.root & "/.project" );
	}

	/**
	 * Checks the files written for a detected VS Code project.
	 */
	private void function wroteFiles() {
		var results = variables.service.write( variables.builder.build( variables.root ) );
		assertEquals( 1, results.len(), "one editor detected" );
		assertEquals( "vscode", results[ 1 ].ide, "detected editor" );
		assertEquals( ".vscode/settings.json", results[ 1 ].files.toList(), "files written" );
		var settings = deserializeJSON( fileRead( variables.root & "/.vscode/settings.json" ) );
		assertEquals( "libs/**/*.jar", settings[ "java.project.referencedLibraries" ][ "include" ][ 1 ], "live dependency glob" );
		assertEquals( "build/ide/classes", settings[ "java.project.outputPath" ], "output directory" );
		assertEquals( "src/generated", settings[ "java.project.sourcePaths" ][ 2 ], "second source root" );
	}

	/**
	 * Checks that every editor's metadata resolves the fixture dependency, by compiling against it.
	 */
	private void function resolvesDependencies() {
		// Generate for every editor, then let javac prove each one resolves the jar.
		fileWrite( variables.root & "/.project", "<projectDescription/>" );
		directoryCreate( variables.root & "/.idea", true );
		variables.service.write( variables.builder.build( variables.root ) );

		var settings = deserializeJSON( fileRead( variables.root & "/.vscode/settings.json" ) );
		var glob = wirebox.getInstance( "Globber" )
			.setPattern( variables.root & "/" & settings[ "java.project.referencedLibraries" ][ "include" ][ 1 ] ).matches();
		assertEquals( 1, glob.len(), "glob matches the installed jar" );
		compileJava( variables.root & "/src/main/java/App.java", variables.root & "/out-vscode", glob.toList() );

		var classpath = xmlParse( fileRead( variables.root & "/.classpath" ) );
		var eclipseJar = xmlSearch( classpath, "/classpath/classpathentry[@kind='lib']" )[ 1 ].xmlAttributes.path;
		compileJava( variables.root & "/src/main/java/App.java", variables.root & "/out-eclipse", variables.root & "/" & eclipseJar );

		var module = xmlParse( fileRead( variables.root & "/commandbox-java.iml" ) );
		var ideaUrl = xmlSearch( module, "//orderEntry[@type='module-library']/library/CLASSES/root" )[ 1 ].xmlAttributes.url;
		// Built from char codes so the test does not embed the $MODULE_DIR$ placeholder.
		var slash = chr( 47 );
		var dollar = chr( 36 );
		var moduleDirUrl = "jar" & chr( 58 ) & slash & slash & dollar & "MODULE_DIR" & dollar & slash;
		var ideaJar = replace( replace( ideaUrl, moduleDirUrl, variables.root & slash ), "!", "", "one" );
		compileJava( variables.root & "/src/main/java/App.java", variables.root & "/out-intellij", ideaJar );
	}

	/**
	 * Checks that a second run changes nothing.
	 */
	private void function idempotent() {
		var before = fileHashes();
		variables.service.write( variables.builder.build( variables.root ) );
		assertEquals( before, fileHashes(), "second run changes nothing" );
	}

	/**
	 * Checks that settings and entries we do not own survive a run.
	 */
	private void function preservesUserMetadata() {
		var classpath = fileRead( variables.root & "/.classpath" );
		fileWrite( variables.root & "/.classpath", replace(
			classpath, "</classpath>", '<classpathentry kind="lib" path="user.jar"/></classpath>'
		) );
		var settings = deserializeJSON( fileRead( variables.root & "/.vscode/settings.json" ) );
		settings[ "user.setting" ] = "keep";
		fileWrite( variables.root & "/.vscode/settings.json", serializeJSON( settings ) );
		fileAppend( variables.root & "/.settings/org.eclipse.jdt.core.prefs", "user.preference=keep" & chr( 10 ) );

		variables.service.write( variables.builder.build( variables.root ) );

		settings = deserializeJSON( fileRead( variables.root & "/.vscode/settings.json" ) );
		assertEquals( "keep", settings[ "user.setting" ], "unrelated JSON key kept" );
		assertEquals( 2, settings[ "editor.tabSize" ], "pre-existing JSON key kept" );
		assertTrue( fileRead( variables.root & "/.classpath" ).contains( "user.jar" ), "unrelated Eclipse entry kept" );
		assertTrue(
			fileRead( variables.root & "/.settings/org.eclipse.jdt.core.prefs" ).contains( "user.preference" ),
			"unrelated Eclipse preference kept"
		);
	}

	/**
	 * Checks that a dependency upgrade is reflected by each editor format.
	 */
	private void function dependencyChanges() {
		fileMove( variables.root & "/libs/nested/greeting-1.0.jar", variables.root & "/libs/nested/greeting-2.0.jar" );
		// VS Code points at the directory, so an install alone keeps it working.
		var settings = deserializeJSON( fileRead( variables.root & "/.vscode/settings.json" ) );
		assertEquals( "libs/**/*.jar", settings[ "java.project.referencedLibraries" ][ "include" ][ 1 ], "glob needs no regeneration" );
		// The Eclipse and IntelliJ formats list jars, so they refresh on re-run.
		fileDelete( variables.root & "/.project" );
		variables.service.write( variables.builder.build( variables.root ) );
		for( var path in [ ".classpath", "commandbox-java.iml" ] ) {
			var content = fileRead( variables.root & "/" & path );
			assertTrue( content.contains( "greeting-2.0.jar" ), "#path# picks up the new jar" );
			assertTrue( !content.contains( "greeting-1.0.jar" ), "#path# drops the old jar" );
		}
	}

	/**
	 * Checks the console output of the command.
	 */
	private void function reportsToTheUser() {
		// The command works on the current directory, so run it from the fixture.
		var previous = getCWD();
		shell.cd( variables.root );
		try {
			variables.command.reset();
			variables.command.run();
		} finally {
			shell.cd( previous );
		}
		var output = variables.command.getResult();
		assertTrue( output.contains( "vscode" ), "reports the editors detected" );
		assertTrue( output.contains( ".vscode/settings.json" ), "reports the files created" );
	}

	/**
	 * Checks that an empty classPath and testClassPath still point the editor at the convention directories.
	 */
	private void function defaultClassPaths() {
		// A freshly `java init`-ed project leaves classPath and testClassPath empty.
		// The editor still has to be pointed at the convention directories, or the
		// language server resolves no jars and JUnit is invisible.
		var config = duplicate( variables.config );
		config.java.classPath = [];
		config.java.testClassPath = [];
		fileWrite( variables.root & "/box.json", serializeJSON( config ) );
		try {
			var model = variables.builder.build( variables.root );
			assertEquals( 1, model.classPath.len(), "runtime classpath defaults to one entry" );
			assertTrue( model.classPath[ 1 ].path.replace( "\", "/", "all" ).endsWith( "dist/dependencies" ), "runtime default directory" );
			assertEquals( 1, model.testClassPath.len(), "test classpath defaults to one entry" );
			assertTrue( model.testClassPath[ 1 ].path.replace( "\", "/", "all" ).endsWith( "dist/test-dependencies" ), "test default directory" );

			variables.service.write( model, "vscode" );
			var settings = deserializeJSON( fileRead( variables.root & "/.vscode/settings.json" ) );
			var includes = settings[ "java.project.referencedLibraries" ][ "include" ];
			assertTrue( includes.find( "dist/dependencies/**/*.jar" ), "runtime dependency glob is written" );
			assertTrue( includes.find( "dist/test-dependencies/**/*.jar" ), "test dependency glob is written" );
		} finally {
			variables.config.java.classPath = [ "libs" ];
			saveConfig();
		}
	}

	/**
	 * Checks that ide= targets a single editor.
	 */
	private void function forcedEditor() {
		// ide= targets one editor even when nothing is detected
		var results = variables.service.write( variables.builder.build( variables.root ), "intellij" );
		assertEquals( 1, results.len(), "one forced editor" );
		assertEquals( "intellij", results[ 1 ].ide, "forced editor id" );
	}

	/**
	 * Checks that an unknown editor id is reported through error().
	 */
	private void function unknownEditorIsGraceful() {
		var message = "";
		var detail = "";
		var previous = getCWD();
		shell.cd( variables.root );
		try {
			variables.command.reset();
			try {
				variables.command.run( ide="bogus" );
			} catch( any e ) {
				message = e.message;
				detail = e.detail ?: "";
			}
		} finally {
			shell.cd( previous );
		}
		assertTrue( message.contains( "Unknown editor" ), "reports an unknown editor id" );
		assertTrue( detail.contains( "vscode" ), "lists the valid editors" );
	}

	/**
	 * Checks that a project with no editor marker falls back to VS Code instead of failing.
	 */
	private void function defaultsToVSCodeWhenNoEditor() {
		directoryDelete( variables.root & "/.vscode", true );
		directoryDelete( variables.root & "/.idea", true );
		fileDelete( variables.root & "/.classpath" );
		// The generated .iml is itself an IntelliJ marker, so clear it too.
		if( fileExists( variables.root & "/commandbox-java.iml" ) ) fileDelete( variables.root & "/commandbox-java.iml" );
		if( fileExists( variables.root & "/.project" ) ) fileDelete( variables.root & "/.project" );
		if( directoryExists( variables.root & "/.settings" ) ) directoryDelete( variables.root & "/.settings", true );

		// Nothing detected is no longer an error from the service
		var results = variables.service.write( variables.builder.build( variables.root ) );
		assertEquals( 0, results.len(), "detecting no editor writes nothing" );

		// The command still produces useful metadata, so `java init` then
		// `java ide-init` works in a folder with no editor marker yet.
		var previous = getCWD();
		shell.cd( variables.root );
		try {
			variables.command.reset();
			variables.command.run();
		} finally {
			shell.cd( previous );
		}
		assertTrue( fileExists( variables.root & "/.vscode/settings.json" ), "falls back to VS Code" );
		assertTrue( variables.command.getResult().contains( "No editor detected" ), "explains the fallback" );
	}

	/**
	 * Detects the editors in use in the fixture, in registry order.
	 *
	 * @root The project root to inspect.
	 * @returns The comma-delimited editor ids.
	 */
	private string function detect( required string root ) {
		var found = [];
		for( var id in [ "vscode", "intellij", "eclipse" ] ) {
			var emitter = wirebox.getInstance( emitterCfc( id ) );
			if( emitter.detect( arguments.root ) ) found.append( id );
		}
		// Return in registry order so the assertion order is predictable.
		return [ "vscode", "intellij", "eclipse" ].filter( function( id ) {
			return found.find( id );
		} ).toList();
	}

	/**
	 * Hashes the generated files so idempotency can be checked.
	 * @returns The path to hash map.
	 */
	private struct function fileHashes() {
		var result = {};
		for( var path in [ ".vscode/settings.json", ".classpath", ".project", ".settings/org.eclipse.jdt.core.prefs", "commandbox-java.iml" ] ) {
			if( fileExists( variables.root & "/" & path ) ) {
				result[ path ] = hash( fileRead( variables.root & "/" & path ) );
			}
		}
		return result;
	}

	/**
	 * Writes the fixture's box.json from the current config.
	 */
	private void function saveConfig() {
		fileWrite( variables.root & "/box.json", serializeJSON( variables.config ) );
	}

	/**
	 * Turns a filesystem path into a WireBox component path.
	 *
	 * @path The path to convert.
	 * @returns The dotted component path.
	 */
	private string function componentPath( required string path ) {
		return listChangeDelims( wirebox.getInstance( "FileSystem" ).makePathRelative( arguments.path ), ".", "/\" );
	}

	/**
	 * Resolves the emitter CFC path for an editor id.
	 *
	 * @id The editor id.
	 * @returns The emitter component path.
	 */
	private string function emitterCfc( required string id ) {
		var classNames = { "vscode" : "VSCode", "eclipse" : "Eclipse", "intellij" : "IntelliJ" };
		return variables.system & ".util.javaide." & classNames[ arguments.id ];
	}

	/**
	 * Compiles one Java source file with javac and returns any diagnostics.
	 *
	 * @source The Java source file to compile.
	 * @output The directory to write classes into.
	 * @string The string.
	 * @classpath Optional classpath entries for javac.
	 * @returns The javac diagnostics.
	 */
	private string function compileJava( required string source, required string output, string classpath="" ) {
		var compiler = createObject( "java", "javax.tools.ToolProvider" ).getSystemJavaCompiler();
		if( isNull( compiler ) ) throw( message="This test needs a JDK, not a JRE." );
		directoryCreate( arguments.output, true, true );
		var manager = compiler.getStandardFileManager( javaCast( "null", "" ), javaCast( "null", "" ), javaCast( "null", "" ) );
		var diagnostics = createObject( "java", "java.io.StringWriter" ).init();
		var options = [ "--release", "17", "-d", arguments.output ];
		if( len( arguments.classpath ) ) options.append( [ "-classpath", arguments.classpath ], true );
		try {
			var succeeded = compiler.getTask(
				diagnostics, manager, javaCast( "null", "" ), options, javaCast( "null", "" ),
				manager.getJavaFileObjects( arguments.source )
			).call();
			assertTrue( succeeded, "compiling failed: #diagnostics.toString()#" );
		} finally {
			manager.close();
		}
		return diagnostics.toString();
	}

	/**
	 * Asserts that a condition is true.
	 *
	 * @condition The condition to check.
	 * @message The failure message.
	 */
	private void function assertTrue( required boolean condition, required string message ) {
		if( !arguments.condition ) throw( message=arguments.message );
	}

	/**
	 * Asserts that two values are equal.
	 *
	 * @expected The expected value.
	 * @actual The actual value.
	 * @message The failure message.
	 */
	private void function assertEquals( required any expected, required any actual, required string message ) {
		if( isStruct( arguments.expected ) && isStruct( arguments.actual ) ) {
			for( var key in arguments.expected ) {
				if( !structKeyExists( arguments.actual, key ) ) {
					throw( message="#arguments.message#: #key# is missing" );
				}
				if( arguments.actual[ key ] != arguments.expected[ key ] ) {
					throw( message="#arguments.message#: #key# changed" );
				}
			}
			assertTrue(
				structCount( arguments.expected ) == structCount( arguments.actual ),
				"#arguments.message#: file list changed"
			);
			return;
		}
		if( arguments.expected == arguments.actual ) return;
		throw( message="#arguments.message#: expected [#arguments.expected#], got [#arguments.actual#]" );
	}
}

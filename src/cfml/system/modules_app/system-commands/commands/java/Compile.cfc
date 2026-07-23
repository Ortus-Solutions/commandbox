/**
 * Compile Java source code and optionally create JARs, Javadocs, or fat JARs.
 *
 * {code:bash}
 * java compile
 * java compile source=src/main/java jar=example.jar
 * java compile compileOptions:release=8 jarOptions:mainClass=example.App
 * java compile manifest:Main-Class=example.App --JSON
 * {code}
 *
 * Compilation uses any available JDK unless a `release`, `source`, or `target`
 * option requires a specific minimum version. Java 21 is downloaded as the
 * fallback when no suitable JDK is available.
 *
 * Complex options use the `name:key=value` syntax. Repeated entries are merged
 * into a struct. Comma-delimited values are converted to arrays for options that
 * accept lists.
 **/
component extends="commandbox.system.BaseCommand" {

	/**
	 * @projectRoot Project directory used as the path-resolution root
	 * @projectRoot.optionsDirectoryComplete true
	 * @source Java source directory, file, glob, or comma-delimited list
	 * @source.optionsFileComplete true
	 * @source.optionsDirectoryComplete true
	 * @classes Compiled class output directory
	 * @classes.optionsDirectoryComplete true
	 * @libsDir JAR output directory
	 * @libsDir.optionsDirectoryComplete true
	 * @resources Resource directory to include in a JAR
	 * @resources.optionsDirectoryComplete true
	 * @manifest Manifest entries supplied as manifest:Name=value
	 * @compileOptions Javac options supplied as compileOptions:Name=value
	 * @jarOptions Jar options supplied as jarOptions:Name=value
	 * @classPath JAR, JAR directory, or comma-delimited list
	 * @classPath.optionsFileComplete true
	 * @classPath.optionsDirectoryComplete true
	 * @jar Create a JAR
	 * @jarName JAR filename
	 * @jarName.optionsFileComplete true
	 * @fatJar Create a fat JAR
	 * @fatJarName Fat JAR filename
	 * @fatJarName.optionsFileComplete true
	 * @fatJarJars Dependency JARs or directories for a fat JAR
	 * @fatJarJars.optionsFileComplete true
	 * @fatJarJars.optionsDirectoryComplete true
	 * @fatJarOptions Fat JAR options supplied as fatJarOptions:Name=value
	 * @javaDocs Generate Javadocs
	 * @verbose Show verbose compiler and JAR output
	 * @JSON Return the compile result without the text overview
	 */
	function run(
		string projectRoot="",
		string source="",
		string classes="",
		string libsDir="",
		string resources="",
		struct manifest={},
		struct compileOptions={},
		struct jarOptions={},
		string classPath="",
		boolean jar=false,
		string jarName="",
		boolean fatJar=false,
		string fatJarName="",
		string fatJarJars="",
		struct fatJarOptions={},
		boolean javaDocs=false,
		boolean verbose=false,
		boolean JSON=false
	) {
		var dsl = compile( arguments.projectRoot );
		if( !isNull( arguments.source ) && len( arguments.source & "" ) ) dsl.fromSource( arguments.source );
		if( len( arguments.classes ) ) dsl.toClasses( arguments.classes );
		if( len( arguments.libsDir ) ) dsl.libsDir( arguments.libsDir );
		if( len( arguments.resources ) ) dsl.withResources( arguments.resources );
		if( !isNull( arguments.classPath ) && len( arguments.classPath & "" ) ) dsl.withClassPath( arguments.classPath );
		if( structCount( arguments.compileOptions ) ) dsl.compileOptions( normalizeOptions( arguments.compileOptions ) );
		if( structCount( arguments.jarOptions ) ) dsl.jarOptions( normalizeOptions( arguments.jarOptions ) );
		if( structCount( arguments.manifest ) ) dsl.manifest( arguments.manifest );
		if( arguments.javaDocs ) dsl.withJavaDocs();
		if( arguments.verbose ) dsl.setVerbose( true );

		if( arguments.jar || len( arguments.jarName ) ) {
			dsl.toJar( arguments.jarName );
		}
		if( arguments.fatJar || len( arguments.fatJarName ) ) {
			dsl.toFatJar( arguments.fatJarName, arguments.fatJarJars, arguments.fatJarOptions );
		}

		var result = dsl.run();
		if( arguments.JSON ) {
			print.line( result );
			return;
		}

		printOverview( result );
	}

	private struct function normalizeOptions( required struct options ) {
		var normalized = {};
		var listKeys = [
			"debug", "lint", "processors", "processorPath", "sourcePath", "modulePath",
			"moduleSourcePath", "addModules", "limitModules"
		];
		for( var key in arguments.options ) {
			var value = arguments.options[ key ];
			if( listKeys.findNoCase( key ) && isSimpleValue( value ) && find( ",", value ) ) {
				value = listToArray( value, ",", true );
			}
			normalized[ key ] = value;
		}
		return normalized;
	}

	private void function printOverview( required struct result ) {
		print.greenLine( "Java compilation completed." );
		print.line( "Project root: #result.projectRoot#" );
		print.line( "Classes: #result.classOutputDirectory#" );
		if( len( result.jarPath ) ) print.line( "JAR: #result.jarPath#" );
		if( len( result.javaDocsPath ) ) print.line( "Javadocs: #result.javaDocsPath#" );
		if( len( result.fatJarPaths ) ) print.line( "Fat JAR dependencies: #result.fatJarPaths.len()#" );
	}

}
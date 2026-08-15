component {

	property name="workingDirectoryStack" type="array";

	function run() {
		this.$bx.meta.functions
			.filter( function( functionMetadata ) {
				return functionMetadata.annotations.keyExists( "test" );
			} )
			.each( function( functionMetadata ) {
				print.line().yellowLine( "── Running #functionMetadata.name# ──" ).toConsole();
				invoke( this, functionMetadata.name );
				print.greenLine( "✓ #functionMetadata.name# passed" ).toConsole();
			} );
	}

	function preTask() {
		if( !structKeyExists( variables, "workingDirectoryStack" ) ) {
			variables.workingDirectoryStack = [];
		}
		variables.workingDirectoryStack.append( getCWD() );
		shell.cd( getDirectoryFromPath( getCurrentTemplatePath() ) );
	}

	function postTask() {
		if( structKeyExists( variables, "workingDirectoryStack" ) && variables.workingDirectoryStack.len() ) {
			shell.cd( variables.workingDirectoryStack.pop() );
		}
	}

	/**
	 * @test
	 */
	function compileCommand() {
		var classesDirectory = resolvePath( "classes/command" );
		var jarFile = resolvePath( "build/libs/command-compile.jar" );

		if( directoryExists( classesDirectory ) ) directoryDelete( classesDirectory, true );
		if( fileExists( jarFile ) ) fileDelete( jarFile );

		// java compile source=src/main/java classes=classes/command jarName=command-compile.jar manifest:Implementation-Title="Command Compile Test" compileOptions:release=8 compileOptions:debug=lines,source jarOptions:compress=false --jar --JSON
		var resultJSON = command( "java compile" )
			.params(
				source="src/main/java",
				classes="classes/command",
				jarName="command-compile.jar",
				manifest={ "Implementation-Title" : "Command Compile Test" },
				compileOptions={ "release" : 8, "debug" : "lines,source" },
				jarOptions={ "compress" : false }
			)
			.flags( "jar", "JSON" )
			.run( returnOutput=true );
		var result = deserializeJSON( print.unAnsi( resultJSON ) );

		assertFileExists( classesDirectory & "/example/App.class" );
		assertFileExists( jarFile );
		assertFileExists( result.jarPath );
		assertEquals(
			reReplace( classesDirectory, "[\\/]+$", "" ),
			reReplace( result.classOutputDirectory, "[\\/]+$", "" )
		);
		assertEquals( "--release=8 -g:lines,source", result.compileOptions );
		assertEquals( "0", result.jarOptions );
		assertEquals( "Command Compile Test", result.manifest[ "Implementation-Title" ] );
	}

	/** @test */
	function compileOptionsAllowCompatibleJDK() {
		var result = runCompile( { compileOptions={ "release" : 8 } }, [ "JSON" ] );
		assertEquals( true, result.jdkBinDirectory.len() > 0 );
	}

	/**
	 * @test
	 */
	function compileCommandWithoutJSON() {
		// java compile classes=classes/command-no-json
		var output = command( "java compile" )
			.params(
				classes="classes/command-no-json",
			)
			.run( returnOutput=true );

		if( !output.contains( "Java compilation completed." ) ) {
			error( "Expected the compile command overview in the output." );
		}
	}

	/** @test */
	function resultMetadata() {
		// java compile --JSON
		var result = runCompile( {}, [ "JSON" ] );
		assertStructKeys( result, [ "projectRoot", "jdkBinDirectory", "sourcePaths", "classOutputDirectory", "libsDirectory", "jarPath", "javaDocsPath", "resourcePath", "classPaths", "fatJarPaths", "compileOptions", "jarOptions", "encoding", "manifest" ] );
		assertEquals( "", result.jarPath );
		assertEquals( "", result.javaDocsPath );
	}

	/** @test */
	function nonStandardSourcePath() {
		// java compile source=src/custom/java jarName=non-standard-source.jar --jar --JSON
		var result = runCompile( { source="src/custom/java", jarName="non-standard-source.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "build/classes/java/main/example/custom/SourcePathApp.class" );
		assertFileExists( "build/libs/non-standard-source.jar" );
		classLoad( resolvePath( "build/libs/non-standard-source.jar" ) );
		assertEquals( "non-standard source works", createObject( "java", "example.custom.SourcePathApp" ).init().message() );
	}

	/** @test */
	function multipleSourcePaths() {
		// java compile source=src/main/java,src/custom/java classes=classes/multiple-sources jarName=multiple-sources.jar --jar --JSON
		var result = runCompile( { source="src/main/java,src/custom/java", classes="classes/multiple-sources", jarName="multiple-sources.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/multiple-sources/example/App.class" );
		assertFileExists( "classes/multiple-sources/example/custom/SourcePathApp.class" );
		assertJarEntryExists( resolvePath( "build/libs/multiple-sources.jar" ), "example/App.class" );
		assertJarEntryExists( resolvePath( "build/libs/multiple-sources.jar" ), "example/custom/SourcePathApp.class" );
	}

	/** @test */
	function sourceGlob() {
		// java compile source=src/custom/java/**/*.java classes=classes/source-glob jarName=source-glob.jar --jar --JSON
		var result = runCompile( { source="src/custom/java/**/*.java", classes="classes/source-glob", jarName="source-glob.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/source-glob/example/custom/SourcePathApp.class" );
		assertJarEntryExists( resolvePath( "build/libs/source-glob.jar" ), "example/custom/SourcePathApp.class" );
	}

	/** @test */
	function defaultResources() {
		// java compile jarName=default-resources.jar --jar --JSON
		runCompile( { jarName="default-resources.jar" }, [ "jar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/default-resources.jar" ), "default-resource.txt" );
		assertJarEntryExists( resolvePath( "build/libs/default-resources.jar" ), "nested/default-nested-resource.txt" );
	}

	/** @test */
	function packageMetadata() {
		// java compile projectRoot=package-fixture --jar --JSON
		var result = runCompile( { projectRoot="package-fixture" }, [ "jar", "JSON" ] );
		assertFileExists( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Bundle-Name", "Compile DSL Package" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Bundle-SymbolicName", "compile-dsl-package" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Bundle-Version", "1.2.3" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Implementation-Title", "Package Manifest Override" );
	}

	/** @test */
	function customClassOutput() {
		// java compile classes=classes/custom-output jarName=custom-class-output.jar --jar --JSON
		runCompile( { classes="classes/custom-output", jarName="custom-class-output.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/custom-output/example/App.class" );
		assertJarEntryExists( resolvePath( "build/libs/custom-class-output.jar" ), "example/App.class" );
	}

	/** @test */
	function customLibraryDirectory() {
		// java compile classes=classes/custom-libs libsDir=custom-libs jarName=custom-library-directory.jar --jar --JSON
		runCompile( { classes="classes/custom-libs", libsDir="custom-libs", jarName="custom-library-directory.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/custom-libs/example/App.class" );
		assertJarEntryExists( resolvePath( "custom-libs/custom-library-directory.jar" ), "example/App.class" );
	}

	/** @test */
	function resources() {
		// java compile resources=src/resources-test jarName=resources.jar --jar --JSON
		runCompile( { resources="src/resources-test", jarName="resources.jar" }, [ "jar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/resources.jar" ), "message.txt" );
	}

	/** @test */
	function customManifest() {
		// java compile manifest:Implementation-Title="Compile DSL Test" jarName=custom-manifest.jar --jar --JSON
		runCompile( { manifest={ "Implementation-Title"="Compile DSL Test" }, jarName="custom-manifest.jar" }, [ "jar", "JSON" ] );
		assertJarManifestValue( resolvePath( "build/libs/custom-manifest.jar" ), "Implementation-Title", "Compile DSL Test" );
	}

	/** @test */
	function compilerOptions() {
		// java compile classes=classes/compiler-options compileOptions:release=8 compileOptions:debug=lines,source compileOptions:parameters=true compileOptions:deprecation=true compileOptions:lint=deprecation compileOptions:maxErrors=10 compileOptions:maxWarnings=10 jarName=compiler-options.jar --jar --JSON
		runCompile( { classes="classes/compiler-options", jarName="compiler-options.jar", compileOptions={ "release"=8, "debug"="lines,source", "parameters"=true, "deprecation"=true, "lint"="deprecation", "maxErrors"=10, "maxWarnings"=10 } }, [ "jar", "JSON" ] );
		assertClassMajorVersion( resolvePath( "classes/compiler-options/example/App.class" ), 52 );
	}

	/** @test */
	function jarOptionValues() {
		// java compile jarOptions:compress=false jarOptions:mainClass=example.App jarOptions:date="2026-01-01T00:00:00Z" jarName=jar-option-values.jar --jar --JSON
		runCompile( { jarName="jar-option-values.jar", jarOptions={ "compress"=false, "mainClass"="example.App", "date"="2026-01-01T00:00:00Z" } }, [ "jar", "JSON" ] );
		assertJarEntryCompression( resolvePath( "build/libs/jar-option-values.jar" ), "example/App.class", 0 );
		assertJarManifestValue( resolvePath( "build/libs/jar-option-values.jar" ), "Main-Class", "example.App" );
	}

	/** @test */
	function classPath() {
		// package install id=maven:org.apache.commons:commons-lang3:3.14.0 directory=libs/maven save=false lock=false
		command( "package install" ).params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false ).run();
		// java compile source=src/classpath/java classPath=libs/maven classes=classes/classpath jarName=classpath.jar --jar --JSON
		var result = runCompile( { source="src/classpath/java", classPath="libs/maven", classes="classes/classpath", jarName="classpath.jar" }, [ "jar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/classpath.jar" ), "example/classpath/ClasspathApp.class" );
		classLoad( [ result.classPaths.first(), resolvePath( "build/libs/classpath.jar" ) ] );
		assertEquals( "classpath: Apache commons", createObject( "java", "example.classpath.ClasspathApp" ).init().message() );
	}

	/** @test */
	function multipleClassPaths() {
		runCompile( { jarName="compile-dsl.jar" }, [ "jar", "JSON" ] );
		prepareMavenDependency();
		// java compile source=src/multiple-classpath/java classPath=build/libs/compile-dsl.jar,libs/maven classes=classes/multiple-classpaths jarName=multiple-classpaths.jar --jar --JSON
		runCompile( { source="src/multiple-classpath/java", classPath="build/libs/compile-dsl.jar,libs/maven", classes="classes/multiple-classpaths", jarName="multiple-classpaths.jar" }, [ "jar", "JSON" ] );
		classLoad( resolvePath( "build/libs/multiple-classpaths.jar" ) );
		assertEquals( "multiple: thin jar works / Apache commons", createObject( "java", "example.multipleclasspath.MultiClasspathApp" ).init().message() );
	}

	/** @test */
	function classPathList() {
		// java compile source=src/multiple-classpath/java classPath=build/libs,libs/maven classes=classes/classpath-list jarName=classpath-list.jar --jar --JSON
		runCompile( { source="src/multiple-classpath/java", classPath="build/libs,libs/maven", classes="classes/classpath-list", jarName="classpath-list.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/classpath-list/example/multipleclasspath/MultiClasspathApp.class" );
	}

	/** @test */
	function javaDocs() {
		// java compile javaDocs=true --JSON
		var result = runCompile( { javaDocs=true }, [ "JSON" ] );
		assertFileExists( "build/docs/javadoc/index.html" );
		assertEquals( resolvePath( "build/docs/javadoc" ), result.javaDocsPath );
	}

	/** @test */
	function fatJar() {
		var localDependencyJar = "build/libs/compile-dsl-fat-#createUUID()#.jar";
		runCompile( { jarName=listLast( localDependencyJar, "/\\" ) }, [ "jar", "JSON" ] );
		prepareMavenDependency();
		var dependencyJar = directoryList( "libs/maven", true, "array", "*.jar" ).first();
		// java compile source=src/multiple-classpath/java classPath=build/libs/compile-dsl-fat-<uuid>.jar,libs/maven classes=classes/fat-jar fatJarName=fat-jar.jar fatJarJars=build/libs/compile-dsl-fat-<uuid>.jar,#dependencyJar# --fatJar --JSON
		runCompile( { source="src/multiple-classpath/java", classPath="#localDependencyJar#,libs/maven", classes="classes/fat-jar", fatJarName="fat-jar.jar", fatJarJars="#localDependencyJar#,#dependencyJar#" }, [ "fatJar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar.jar" ), "example/multipleclasspath/MultiClasspathApp.class" );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar.jar" ), "example/App.class" );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar.jar" ), "org/apache/commons/lang3/StringUtils.class" );
	}

	/** @test */
	function thinAndFatJar() {
		runCompile( { jarName="compile-dsl.jar" }, [ "jar", "JSON" ] );
		prepareMavenDependency();
		var dependencyJar = directoryList( "libs/maven", true, "array", "*.jar" ).first();
		// java compile source=src/multiple-classpath/java classPath=build/libs/compile-dsl.jar,libs/maven jarName=thin-and-fat.jar fatJarName=thin-and-fat-all.jar fatJarJars=build/libs/compile-dsl.jar,#dependencyJar# --JSON
		var result = runCompile( { source="src/multiple-classpath/java", classPath="build/libs/compile-dsl.jar,libs/maven", jarName="thin-and-fat.jar", fatJarName="thin-and-fat-all.jar", fatJarJars="build/libs/compile-dsl.jar,#dependencyJar#" }, [ "JSON" ] );
		assertFileExists( "build/libs/thin-and-fat.jar" );
		assertFileExists( "build/libs/thin-and-fat-all.jar" );
		assertJarEntryMissing( resolvePath( "build/libs/thin-and-fat.jar" ), "org/apache/commons/lang3/StringUtils.class" );
		assertJarEntryExists( resolvePath( "build/libs/thin-and-fat-all.jar" ), "org/apache/commons/lang3/StringUtils.class" );
	}

	/** @test */
	function fatJarServiceDescriptors() {
		if( fileExists( "build/libs/fat-jar-services.jar" ) ) fileDelete( "build/libs/fat-jar-services.jar" );
		createServiceDependencyJar( "fat-jar-services/one", "libs/fat-jar-service-one.jar", "example.provider.First", "DEPENDENCY.SF" );
		createServiceDependencyJar( "fat-jar-services/two", "libs/fat-jar-service-two.jar", "example.provider.Second" );
		// java compile fatJarName=fat-jar-services.jar fatJarJars=libs/fat-jar-service-one.jar,libs/fat-jar-service-two.jar --fatJar --JSON
		runCompile( { fatJarName="fat-jar-services.jar", fatJarJars="libs/fat-jar-service-one.jar,libs/fat-jar-service-two.jar" }, [ "fatJar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar-services.jar" ), "META-INF/services/example.Service" );
		assertJarEntryMissing( resolvePath( "build/libs/fat-jar-services.jar" ), "META-INF/DEPENDENCY.SF" );
		assertEquals( "example.provider.First#chr(10)#example.provider.Second", readJarEntry( resolvePath( "build/libs/fat-jar-services.jar" ), "META-INF/services/example.Service" ) );
	}

	/** @test */
	function fatJarDuplicateResources() {
		createResourceDependencyJar( "fat-jar-duplicates/first", "libs/fat-jar-duplicate-first.jar", "first dependency" );
		createResourceDependencyJar( "fat-jar-duplicates/second", "libs/fat-jar-duplicate-second.jar", "second dependency" );
		// java compile fatJarName=fat-jar-duplicates.jar fatJarJars=libs/fat-jar-duplicate-first.jar,libs/fat-jar-duplicate-second.jar --fatJar --JSON
		runCompile( { fatJarName="fat-jar-duplicates.jar", fatJarJars="libs/fat-jar-duplicate-first.jar,libs/fat-jar-duplicate-second.jar" }, [ "fatJar", "JSON" ] );
		assertEquals( "second dependency", readJarEntry( resolvePath( "build/libs/fat-jar-duplicates.jar" ), "duplicate-resource.txt" ) );
	}

	/** @test */
	function fatJarMergeOptions() {
		createServiceDependencyJar( "fat-jar-options/one", "libs/fat-jar-options-one.jar", "example.provider.First", "DEPENDENCY.SF" );
		createServiceDependencyJar( "fat-jar-options/two", "libs/fat-jar-options-two.jar", "example.provider.Second" );
		// java compile fatJarName=fat-jar-options.jar fatJarJars=libs/fat-jar-options-one.jar,libs/fat-jar-options-two.jar fatJarOptions:mergeServiceDescriptors=false fatJarOptions:excludeSignatures=false --fatJar --JSON
		runCompile( { fatJarName="fat-jar-options.jar", fatJarJars="libs/fat-jar-options-one.jar,libs/fat-jar-options-two.jar", fatJarOptions={ "mergeServiceDescriptors"=false, "excludeSignatures"=false } }, [ "fatJar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar-options.jar" ), "META-INF/DEPENDENCY.SF" );
		assertEquals( "example.provider.Second", readJarEntry( resolvePath( "build/libs/fat-jar-options.jar" ), "META-INF/services/example.Service" ) );
	}

	/** @test */
	function fatJarDuplicatePolicies() {
		createResourceDependencyJar( "fat-jar-policies/first", "libs/fat-jar-policy-first.jar", "first dependency" );
		createResourceDependencyJar( "fat-jar-policies/second", "libs/fat-jar-policy-second.jar", "second dependency" );
		// java compile fatJarName=fat-jar-policy-first-wins.jar fatJarJars=libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar fatJarOptions:duplicatePolicy=first --fatJar --JSON
		runCompile( { fatJarName="fat-jar-policy-first-wins.jar", fatJarJars="libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar", fatJarOptions={ "duplicatePolicy"="first" } }, [ "fatJar", "JSON" ] );
		assertEquals( "first dependency", readJarEntry( resolvePath( "build/libs/fat-jar-policy-first-wins.jar" ), "duplicate-resource.txt" ) );
		var duplicateFailed = false;
		try {
			// java compile fatJarName=fat-jar-policy-error.jar fatJarJars=libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar fatJarOptions:duplicatePolicy=error --fatJar --JSON
			runCompile( { fatJarName="fat-jar-policy-error.jar", fatJarJars="libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar", fatJarOptions={ "duplicatePolicy"="error" } }, [ "fatJar", "JSON" ] );
		} catch( any e ) { duplicateFailed = true; }
		assertEquals( true, duplicateFailed );
	}

	/** @test */
	function failedCompileCleanup() {
		var tempDirectory = getInstance( "tempDir@constants" );
		var beforeTempFiles = directoryList( tempDirectory, false, "array", "temp*.txt" );
		var compileFailed = false;
		try {
			// java compile source=src/invalid/java classes=classes/invalid-source --JSON
			runCompile( { source="src/invalid/java", classes="classes/invalid-source" }, [ "JSON" ] );
		} catch( any e ) { compileFailed = true; }
		assertEquals( true, compileFailed );
		assertEquals( beforeTempFiles.sort( "textnocase" ).toList( chr(10) ), directoryList( tempDirectory, false, "array", "temp*.txt" ).sort( "textnocase" ).toList( chr(10) ) );
	}

	/** @test */
	function jarOptions() {
		// java compile jarOptions:compress=false jarName=jar-options.jar --jar --JSON
		runCompile( { jarName="jar-options.jar", jarOptions={ "compress"=false } }, [ "jar", "JSON" ] );
		assertJarEntryCompression( resolvePath( "build/libs/jar-options.jar" ), "example/App.class", 0 );
	}

	/** @test */
	function sourceEncoding() {
		// java compile source=src/encoding/java compileOptions:encoding=UTF-8 classes=classes/source-encoding jarName=source-encoding.jar --jar --JSON
		runCompile( { source="src/encoding/java", classes="classes/source-encoding", jarName="source-encoding.jar", compileOptions={ "encoding"="UTF-8" } }, [ "jar", "JSON" ] );
		classLoad( resolvePath( "build/libs/source-encoding.jar" ) );
		assertEquals( "café", createObject( "java", "example.encoding.EncodingApp" ).init().message() );
	}

	/** @test */
	function optionsValidation() {
		var compilerFailed = false;
		var jarFailed = false;
		try { runCompile( { compileOptions={ "unknown"=true } }, [ "JSON" ] ); } catch( any e ) { compilerFailed = true; }
		try { runCompile( { jarOptions={ "unknown"=true } }, [ "JSON" ] ); } catch( any e ) { jarFailed = true; }
		assertEquals( true, compilerFailed );
		assertEquals( true, jarFailed );
	}

	/** @test */
	function boxJsonDefaults() {
		// java compile projectRoot=boxjson-fixture --JSON
		cleanBoxJsonFixture();
		var result = runCompile( { projectRoot="boxjson-fixture" }, [ "JSON" ] );
		assertFileExists( "boxjson-fixture/custom-classes/example/boxjson/BoxJsonApp.class" );
		assertFileExists( "boxjson-fixture/custom-libs/boxjson-app.jar" );
		assertJarManifestValue( resolvePath( "boxjson-fixture/custom-libs/boxjson-app.jar" ), "Implementation-Title", "BoxJSON Override" );
		assertEquals( reReplace( resolvePath( "boxjson-fixture/custom-classes" ), "[\\/]+$", "" ), reReplace( result.classOutputDirectory, "[\\/]+$", "" ) );
		assertEquals( reReplace( resolvePath( "boxjson-fixture/custom-libs" ), "[\\/]+$", "" ), reReplace( result.libsDirectory, "[\\/]+$", "" ) );
	}

	/** @test */
	function boxJsonCliDisable() {
		// java compile projectRoot=boxjson-fixture jar=false javaDocs=false --JSON
		cleanBoxJsonFixture();
		runCompile( { projectRoot="boxjson-fixture", jar=false, javaDocs=false }, [ "JSON" ] );
		assertFileExists( "boxjson-fixture/custom-classes/example/boxjson/BoxJsonApp.class" );
		assertFileMissing( "boxjson-fixture/custom-libs/boxjson-app.jar" );
	}

	/** @test */
	function boxJsonCliOverride() {
		// java compile projectRoot=boxjson-fixture jarName=cli-override.jar --JSON
		cleanBoxJsonFixture();
		runCompile( { projectRoot="boxjson-fixture", jarName="cli-override.jar" }, [ "JSON" ] );
		assertFileExists( "boxjson-fixture/custom-libs/cli-override.jar" );
		assertFileMissing( "boxjson-fixture/custom-libs/boxjson-app.jar" );
	}

	/** @test */
	function boxJsonCompileOptionsMerge() {
		// java compile projectRoot=boxjson-fixture compileOptions:parameters=true --JSON
		cleanBoxJsonFixture();
		var result = runCompile( { projectRoot="boxjson-fixture", compileOptions={ "parameters"=true } }, [ "JSON" ] );
		// release=8 comes from box.json, parameters=true comes from the CLI.
		// Both should be present because structs merge instead of replacing.
		assertEquals( true, find( "--release=8", result.compileOptions ) > 0 );
		assertEquals( true, find( "-parameters", result.compileOptions ) > 0 );
	}

	/** @test */
	function javaInit() {
		var fixtureDir = resolvePath( "java-init-fixture" );
		if( directoryExists( fixtureDir ) ) directoryDelete( fixtureDir, true );
		directoryCreate( fixtureDir, true );

		var originalDir = getCWD();
		shell.cd( fixtureDir );
		try {
			// No box.json yet — this runs `package init` first, then adds java config
			command( "java init" ).run();
		} finally {
			shell.cd( originalDir );
		}

		assertFileExists( "java-init-fixture/box.json" );
		var boxJSON = deserializeJSON( fileRead( fixtureDir & "/box.json" ) );
		assertEquals( "src/main/java", boxJSON.java.source );
		assertEquals( "build/classes/java/main", boxJSON.java.classes );
		assertEquals( "build/libs", boxJSON.java.libsDir );
		assertEquals( "src/main/resources", boxJSON.java.resources );
		assertEquals( "build/docs/javadoc", boxJSON.java.javaDocsDir );
		assertFileExists( "java-init-fixture/src/main/java/example/Example.java" );
		assertEquals( true, boxJSON.java.jar );
		assertEquals( "example.Example", boxJSON.java.jarOptions.mainClass );
		assertEquals( true, directoryExists( "java-init-fixture/src/main/resources" ) );

		print.greenLine( "Java init test passed." );
	}

	/** @test */
	function javaInitCustomFolders() {
		var fixtureDir = resolvePath( "java-init-custom-fixture" );
		if( directoryExists( fixtureDir ) ) directoryDelete( fixtureDir, true );
		directoryCreate( fixtureDir, true );
		fileWrite( fixtureDir & "/box.json", '{ "name" : "Custom", "slug" : "custom", "version" : "1.0.0" }' );

		var originalDir = getCWD();
		shell.cd( fixtureDir );
		try {
			command( "java init" ).params( source="src/custom/java", classes="build/out", libsDir="dist" ).run();
		} finally {
			shell.cd( originalDir );
		}

		var boxJSON = deserializeJSON( fileRead( fixtureDir & "/box.json" ) );
		assertEquals( "src/custom/java", boxJSON.java.source );
		assertEquals( "build/out", boxJSON.java.classes );
		assertEquals( "dist", boxJSON.java.libsDir );
		assertFileExists( "java-init-custom-fixture/src/custom/java/example/Example.java" );
		assertEquals( true, directoryExists( "java-init-custom-fixture/build/out" ) );

		print.greenLine( "Java init custom folders test passed." );
	}

	private function cleanBoxJsonFixture() {
		[ "custom-classes", "custom-libs", "build" ].each( function( dir ) {
			var path = resolvePath( "boxjson-fixture/#dir#" );
			if( directoryExists( path ) ) directoryDelete( path, true );
		} );
	}

	private struct function runCompile( struct params={}, array flags=[] ) {
		var compileCommand = command( "java compile" );
		compileCommand.params( argumentCollection=arguments.params );
		compileCommand.flags( argumentCollection=arguments.flags );
		return deserializeJSON( print.unAnsi( compileCommand.run( returnOutput=true ) ) );
	}

	private void function prepareMavenDependency() {
		if( !directoryExists( "libs/maven" ) ) {
			command( "package install" )
				.params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false )
				.run();
		}
	}

	private function assertFileExists( required string filePath ) {
		if( !fileExists( arguments.filePath ) ) error( "Expected file was not created: #arguments.filePath#" );
	}

	private function assertFileMissing( required string filePath ) {
		if( fileExists( arguments.filePath ) ) error( "Expected file to be missing: #arguments.filePath#" );
	}

	private function assertEquals( required expected, required actual ) {
		if( arguments.expected != arguments.actual ) error( "Expected [#arguments.expected#], received [#arguments.actual#]." );
	}

	private function assertStructKeys( required struct value, required array keys ) {
		for( var key in arguments.keys ) {
			if( !arguments.value.keyExists( key ) ) error( "Expected result key was not returned: #key#" );
		}
	}

	private function assertJarEntryExists( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			if( isNull( jar.getJarEntry( arguments.entryName ) ) ) error( "Expected JAR entry was not found: #arguments.entryName#" );
		} finally {
			jar.close();
		}
	}

	private function assertJarEntryMissing( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			if( !isNull( jar.getJarEntry( arguments.entryName ) ) ) error( "Unexpected JAR entry was found: #arguments.entryName#" );
		} finally {
			jar.close();
		}
	}

	private string function readJarEntry( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			var entry = jar.getJarEntry( arguments.entryName );
			if( isNull( entry ) ) error( "Expected JAR entry was not found: #arguments.entryName#" );
			var input = jar.getInputStream( entry );
			try {
				return createObject( "java", "java.lang.String" ).init( input.readAllBytes(), "UTF-8" ).trim();
			} finally {
				input.close();
			}
		} finally {
			jar.close();
		}
	}

	private function createServiceDependencyJar( required string directory, required string jarFile, required string provider, string signatureFile="" ) {
		var directory = resolvePath( arguments.directory );
		var jarFile = resolvePath( arguments.jarFile );
		if( directoryExists( directory ) ) directoryDelete( directory, true );
		if( fileExists( jarFile ) ) fileDelete( jarFile );
		directoryCreate( directory & "/META-INF/services", true );
		fileWrite( directory & "/META-INF/services/example.Service", arguments.provider & chr(10) );
		if( arguments.signatureFile.len() ) fileWrite( directory & "/META-INF/" & arguments.signatureFile, "invalid signature" );
		var zipFile = jarFile & ".zip";
		if( fileExists( zipFile ) ) fileDelete( zipFile );
		zip action="zip" file="#jarFile#" source="#directory#" overwrite="true";
		fileMove( zipFile, jarFile );
	}

	private function createResourceDependencyJar( required string directory, required string jarFile, required string resourceContents ) {
		var directory = resolvePath( arguments.directory );
		var jarFile = resolvePath( arguments.jarFile );
		if( directoryExists( directory ) ) directoryDelete( directory, true );
		if( fileExists( jarFile ) ) fileDelete( jarFile );
		directoryCreate( directory, true );
		fileWrite( directory & "/duplicate-resource.txt", arguments.resourceContents & chr(10) );
		var zipFile = jarFile & ".zip";
		if( fileExists( zipFile ) ) fileDelete( zipFile );
		zip action="zip" file="#jarFile#" source="#directory#" overwrite="true";
		fileMove( zipFile, jarFile );
	}

	private function assertJarManifestValue( required string jarFile, required string attributeName, required string expectedValue ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			assertEquals( arguments.expectedValue, jar.getManifest().getMainAttributes().getValue( arguments.attributeName ) );
		} finally {
			jar.close();
		}
	}

	private function assertClassMajorVersion( required string classFile, required numeric expectedVersion ) {
		var input = createObject( "java", "java.io.DataInputStream" ).init( createObject( "java", "java.io.FileInputStream" ).init( arguments.classFile ) );
		try {
			input.readInt();
			input.readUnsignedShort();
			assertEquals( arguments.expectedVersion, input.readUnsignedShort() );
		} finally {
			input.close();
		}
	}

	private function assertJarEntryCompression( required string jarFile, required string entryName, required numeric expectedMethod ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			var entry = jar.getJarEntry( arguments.entryName );
			if( isNull( entry ) ) error( "Expected JAR entry was not found: #arguments.entryName#" );
			assertEquals( arguments.expectedMethod, entry.getMethod() );
		} finally {
			jar.close();
		}
	}

}
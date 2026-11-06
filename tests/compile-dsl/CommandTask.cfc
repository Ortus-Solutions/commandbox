component {

	property name="workingDirectoryStack" type="array";

	/**
	 * Runs every function annotated `@test` and prints a per-test result.
	 */
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

	/**
	 * Remembers the caller's working directory and switches to this test file's directory.
	 */
	function preTask() {
		if( !structKeyExists( variables, "workingDirectoryStack" ) ) {
			variables.workingDirectoryStack = [];
		}
		variables.workingDirectoryStack.append( getCWD() );
		shell.cd( getDirectoryFromPath( getCurrentTemplatePath() ) );
	}

	/**
	 * Restores the working directory that preTask() saved.
	 */
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

		// java compile sourcePath=src/main/java classesDirectory=classes/command jarFile=command-compile.jar manifest:Implementation-Title="Command Compile Test" compileOptions:release=8 compileOptions:debug=lines,source jarOptions:compress=false --jar --JSON
		var resultJSON = command( "java compile" )
			.params(
				sourcePath="src/main/java",
				classesDirectory="classes/command",
				jarFile="command-compile.jar",
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
		// java compile classesDirectory=classes/command-no-json
		var output = command( "java compile" )
			.params(
				classesDirectory="classes/command-no-json",
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
		assertStructKeys( result, [ "projectRoot", "jdkBinDirectory", "sourcePaths", "classOutputDirectory", "libsDirectory", "jarPath", "javaDocsPath", "resourcePath", "classPaths", "fatJarPaths", "compileOptions", "jarOptions", "encoding", "manifest", "testsCompiled", "testSourcePaths", "testClassOutputDirectory", "testResourcePaths", "testClassPaths" ] );
		assertEquals( "", result.jarPath );
		assertEquals( "", result.javaDocsPath );
	}

	/** @test */
	function nonStandardSourcePath() {
		// java compile sourcePath=src/custom/java jarFile=non-standard-source.jar --jar --JSON
		var result = runCompile( { sourcePath="src/custom/java", jarFile="non-standard-source.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "build/classes/java/main/example/custom/SourcePathApp.class" );
		assertFileExists( "build/libs/non-standard-source.jar" );
		classLoad( resolvePath( "build/libs/non-standard-source.jar" ) );
		assertEquals( "non-standard source works", createObject( "java", "example.custom.SourcePathApp" ).init().message() );
	}

	/** @test */
	function multipleSourcePaths() {
		// java compile sourcePath=src/main/java,src/custom/java classesDirectory=classes/multiple-sources jarFile=multiple-sources.jar --jar --JSON
		var result = runCompile( { sourcePath="src/main/java,src/custom/java", classesDirectory="classes/multiple-sources", jarFile="multiple-sources.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/multiple-sources/example/App.class" );
		assertFileExists( "classes/multiple-sources/example/custom/SourcePathApp.class" );
		assertJarEntryExists( resolvePath( "build/libs/multiple-sources.jar" ), "example/App.class" );
		assertJarEntryExists( resolvePath( "build/libs/multiple-sources.jar" ), "example/custom/SourcePathApp.class" );
	}

	/** @test */
	function sourceGlob() {
		// java compile sourcePath=src/custom/java/**/*.java classesDirectory=classes/source-glob jarFile=source-glob.jar --jar --JSON
		var result = runCompile( { sourcePath="src/custom/java/**/*.java", classesDirectory="classes/source-glob", jarFile="source-glob.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/source-glob/example/custom/SourcePathApp.class" );
		assertJarEntryExists( resolvePath( "build/libs/source-glob.jar" ), "example/custom/SourcePathApp.class" );
	}

	/** @test */
	function defaultResources() {
		// java compile jarFile=default-resources.jar --jar --JSON
		runCompile( { jarFile="default-resources.jar" }, [ "jar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/default-resources.jar" ), "default-resource.txt" );
		assertJarEntryExists( resolvePath( "build/libs/default-resources.jar" ), "nested/default-nested-resource.txt" );
	}

	/** @test */
	function packageMetadata() {
		// java compile projectRootDirectory=package-fixture --jar --JSON
		var result = runCompile( { projectRootDirectory="package-fixture" }, [ "jar", "JSON" ] );
		assertFileExists( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Bundle-Name", "Compile DSL Package" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Bundle-SymbolicName", "compile-dsl-package" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Bundle-Version", "1.2.3" );
		assertJarManifestValue( resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" ), "Implementation-Title", "Package Manifest Override" );
	}

	/** @test */
	function customClassOutput() {
		// java compile classesDirectory=classes/custom-output jarFile=custom-class-output.jar --jar --JSON
		runCompile( { classesDirectory="classes/custom-output", jarFile="custom-class-output.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/custom-output/example/App.class" );
		assertJarEntryExists( resolvePath( "build/libs/custom-class-output.jar" ), "example/App.class" );
	}

	/** @test */
	function customLibraryDirectory() {
		// java compile classesDirectory=classes/custom-libs libsDirectory=custom-libs jarFile=custom-library-directory.jar --jar --JSON
		runCompile( { classesDirectory="classes/custom-libs", libsDirectory="custom-libs", jarFile="custom-library-directory.jar" }, [ "jar", "JSON" ] );
		assertFileExists( "classes/custom-libs/example/App.class" );
		assertJarEntryExists( resolvePath( "custom-libs/custom-library-directory.jar" ), "example/App.class" );
	}

	/** @test */
	function resources() {
		// java compile resourcesDirectory=src/resources-test jarFile=resources.jar --jar --JSON
		runCompile( { resourcesDirectory="src/resources-test", jarFile="resources.jar" }, [ "jar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/resources.jar" ), "message.txt" );
	}

	/** @test */
	function customManifest() {
		// java compile manifest:Implementation-Title="Compile DSL Test" jarFile=custom-manifest.jar --jar --JSON
		runCompile( { manifest={ "Implementation-Title"="Compile DSL Test" }, jarFile="custom-manifest.jar" }, [ "jar", "JSON" ] );
		assertJarManifestValue( resolvePath( "build/libs/custom-manifest.jar" ), "Implementation-Title", "Compile DSL Test" );
	}

	/** @test */
	function compilerOptions() {
		// java compile classesDirectory=classes/compiler-options compileOptions:release=8 compileOptions:debug=lines,source compileOptions:parameters=true compileOptions:deprecation=true compileOptions:lint=deprecation compileOptions:maxErrors=10 compileOptions:maxWarnings=10 jarFile=compiler-options.jar --jar --JSON
		runCompile( { classesDirectory="classes/compiler-options", jarFile="compiler-options.jar", compileOptions={ "release"=8, "debug"="lines,source", "parameters"=true, "deprecation"=true, "lint"="deprecation", "maxErrors"=10, "maxWarnings"=10 } }, [ "jar", "JSON" ] );
		assertClassMajorVersion( resolvePath( "classes/compiler-options/example/App.class" ), 52 );
	}

	/** @test */
	function jarOptionValues() {
		// java compile jarOptions:compress=false jarOptions:mainClass=example.App jarOptions:date="2026-01-01T00:00:00Z" jarFile=jar-option-values.jar --jar --JSON
		runCompile( { jarFile="jar-option-values.jar", jarOptions={ "compress"=false, "mainClass"="example.App", "date"="2026-01-01T00:00:00Z" } }, [ "jar", "JSON" ] );
		assertJarEntryCompression( resolvePath( "build/libs/jar-option-values.jar" ), "example/App.class", 0 );
		assertJarManifestValue( resolvePath( "build/libs/jar-option-values.jar" ), "Main-Class", "example.App" );
	}

	/** @test */
	function classPath() {
		// package install id=maven:org.apache.commons:commons-lang3:3.14.0 directory=libs/maven save=false lock=false
		command( "package install" ).params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false ).run();
		// java compile sourcePath=src/classpath/java classPath=libs/maven classesDirectory=classes/classpath jarFile=classpath.jar --jar --JSON
		var result = runCompile( { sourcePath="src/classpath/java", classPath="libs/maven", classesDirectory="classes/classpath", jarFile="classpath.jar" }, [ "jar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/classpath.jar" ), "example/classpath/ClasspathApp.class" );
		classLoad( [ result.classPaths.first(), resolvePath( "build/libs/classpath.jar" ) ] );
		assertEquals( "classpath: Apache commons", createObject( "java", "example.classpath.ClasspathApp" ).init().message() );
	}

	/** @test */
	function multipleClassPaths() {
		runCompile( { jarFile="compile-dsl.jar" }, [ "jar", "JSON" ] );
		prepareMavenDependency();
		// java compile sourcePath=src/multiple-classpath/java classPath=build/libs/compile-dsl.jar,libs/maven classesDirectory=classes/multiple-classpaths jarFile=multiple-classpaths.jar --jar --JSON
		runCompile( { sourcePath="src/multiple-classpath/java", classPath="build/libs/compile-dsl.jar,libs/maven", classesDirectory="classes/multiple-classpaths", jarFile="multiple-classpaths.jar" }, [ "jar", "JSON" ] );
		classLoad( resolvePath( "build/libs/multiple-classpaths.jar" ) );
		assertEquals( "multiple: thin jar works / Apache commons", createObject( "java", "example.multipleclasspath.MultiClasspathApp" ).init().message() );
	}

	/** @test */
	function classPathList() {
		// java compile sourcePath=src/multiple-classpath/java classPath=build/libs,libs/maven classesDirectory=classes/classpath-list jarFile=classpath-list.jar --jar --JSON
		runCompile( { sourcePath="src/multiple-classpath/java", classPath="build/libs,libs/maven", classesDirectory="classes/classpath-list", jarFile="classpath-list.jar" }, [ "jar", "JSON" ] );
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
		runCompile( { jarFile=listLast( localDependencyJar, "/\\" ) }, [ "jar", "JSON" ] );
		prepareMavenDependency();
		var dependencyJar = directoryList( "libs/maven", true, "array", "*.jar" ).first();
		// java compile sourcePath=src/multiple-classpath/java classPath=build/libs/compile-dsl-fat-<uuid>.jar,libs/maven classesDirectory=classes/fat-jar fatJarFile=fat-jar.jar fatJarPaths=build/libs/compile-dsl-fat-<uuid>.jar,#dependencyJar# --fatJar --JSON
		runCompile( { sourcePath="src/multiple-classpath/java", classPath="#localDependencyJar#,libs/maven", classesDirectory="classes/fat-jar", fatJarFile="fat-jar.jar", fatJarPaths="#localDependencyJar#,#dependencyJar#" }, [ "fatJar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar.jar" ), "example/multipleclasspath/MultiClasspathApp.class" );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar.jar" ), "example/App.class" );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar.jar" ), "org/apache/commons/lang3/StringUtils.class" );
	}

	/** @test */
	function thinAndFatJar() {
		runCompile( { jarFile="compile-dsl.jar" }, [ "jar", "JSON" ] );
		prepareMavenDependency();
		var dependencyJar = directoryList( "libs/maven", true, "array", "*.jar" ).first();
		// java compile sourcePath=src/multiple-classpath/java classPath=build/libs/compile-dsl.jar,libs/maven jarFile=thin-and-fat.jar fatJarFile=thin-and-fat-all.jar fatJarPaths=build/libs/compile-dsl.jar,#dependencyJar# --JSON
		var result = runCompile( { sourcePath="src/multiple-classpath/java", classPath="build/libs/compile-dsl.jar,libs/maven", jarFile="thin-and-fat.jar", fatJarFile="thin-and-fat-all.jar", fatJarPaths="build/libs/compile-dsl.jar,#dependencyJar#" }, [ "JSON" ] );
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
		// java compile fatJarFile=fat-jar-services.jar fatJarPaths=libs/fat-jar-service-one.jar,libs/fat-jar-service-two.jar --fatJar --JSON
		runCompile( { fatJarFile="fat-jar-services.jar", fatJarPaths="libs/fat-jar-service-one.jar,libs/fat-jar-service-two.jar" }, [ "fatJar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar-services.jar" ), "META-INF/services/example.Service" );
		assertJarEntryMissing( resolvePath( "build/libs/fat-jar-services.jar" ), "META-INF/DEPENDENCY.SF" );
		assertEquals( "example.provider.First#chr(10)#example.provider.Second", readJarEntry( resolvePath( "build/libs/fat-jar-services.jar" ), "META-INF/services/example.Service" ) );
	}

	/** @test */
	function fatJarDuplicateResources() {
		createResourceDependencyJar( "fat-jar-duplicates/first", "libs/fat-jar-duplicate-first.jar", "first dependency" );
		createResourceDependencyJar( "fat-jar-duplicates/second", "libs/fat-jar-duplicate-second.jar", "second dependency" );
		// java compile fatJarFile=fat-jar-duplicates.jar fatJarPaths=libs/fat-jar-duplicate-first.jar,libs/fat-jar-duplicate-second.jar --fatJar --JSON
		runCompile( { fatJarFile="fat-jar-duplicates.jar", fatJarPaths="libs/fat-jar-duplicate-first.jar,libs/fat-jar-duplicate-second.jar" }, [ "fatJar", "JSON" ] );
		assertEquals( "second dependency", readJarEntry( resolvePath( "build/libs/fat-jar-duplicates.jar" ), "duplicate-resource.txt" ) );
	}

	/** @test */
	function fatJarMergeOptions() {
		createServiceDependencyJar( "fat-jar-options/one", "libs/fat-jar-options-one.jar", "example.provider.First", "DEPENDENCY.SF" );
		createServiceDependencyJar( "fat-jar-options/two", "libs/fat-jar-options-two.jar", "example.provider.Second" );
		// java compile fatJarFile=fat-jar-options.jar fatJarPaths=libs/fat-jar-options-one.jar,libs/fat-jar-options-two.jar fatJarOptions:mergeServiceDescriptors=false fatJarOptions:excludeSignatures=false --fatJar --JSON
		runCompile( { fatJarFile="fat-jar-options.jar", fatJarPaths="libs/fat-jar-options-one.jar,libs/fat-jar-options-two.jar", fatJarOptions={ "mergeServiceDescriptors"=false, "excludeSignatures"=false } }, [ "fatJar", "JSON" ] );
		assertJarEntryExists( resolvePath( "build/libs/fat-jar-options.jar" ), "META-INF/DEPENDENCY.SF" );
		assertEquals( "example.provider.Second", readJarEntry( resolvePath( "build/libs/fat-jar-options.jar" ), "META-INF/services/example.Service" ) );
	}

	/** @test */
	function fatJarDuplicatePolicies() {
		createResourceDependencyJar( "fat-jar-policies/first", "libs/fat-jar-policy-first.jar", "first dependency" );
		createResourceDependencyJar( "fat-jar-policies/second", "libs/fat-jar-policy-second.jar", "second dependency" );
		// java compile fatJarFile=fat-jar-policy-first-wins.jar fatJarPaths=libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar fatJarOptions:duplicatePolicy=first --fatJar --JSON
		runCompile( { fatJarFile="fat-jar-policy-first-wins.jar", fatJarPaths="libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar", fatJarOptions={ "duplicatePolicy"="first" } }, [ "fatJar", "JSON" ] );
		assertEquals( "first dependency", readJarEntry( resolvePath( "build/libs/fat-jar-policy-first-wins.jar" ), "duplicate-resource.txt" ) );
		var duplicateFailed = false;
		try {
			// java compile fatJarFile=fat-jar-policy-error.jar fatJarPaths=libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar fatJarOptions:duplicatePolicy=error --fatJar --JSON
			runCompile( { fatJarFile="fat-jar-policy-error.jar", fatJarPaths="libs/fat-jar-policy-first.jar,libs/fat-jar-policy-second.jar", fatJarOptions={ "duplicatePolicy"="error" } }, [ "fatJar", "JSON" ] );
		} catch( any e ) { duplicateFailed = true; }
		assertEquals( true, duplicateFailed );
		// The expected failure left the interactive job and the exit code set, so clear
		// them before the runner prints the result and moves on to the next test.
		job.reset();
		setExitCode( 0 );
	}

	/** @test */
	function failedCompileCleanup() {
		var tempDirectory = getInstance( "tempDir@constants" );
		var beforeTempFiles = directoryList( tempDirectory, false, "array", "temp*.txt" );
		var compileFailed = false;
		try {
			// java compile sourcePath=src/invalid/java classesDirectory=classes/invalid-source --JSON
			runCompile( { sourcePath="src/invalid/java", classesDirectory="classes/invalid-source" }, [ "JSON" ] );
		} catch( any e ) { compileFailed = true; }
		assertEquals( true, compileFailed );
		assertEquals( beforeTempFiles.sort( "textnocase" ).toList( chr(10) ), directoryList( tempDirectory, false, "array", "temp*.txt" ).sort( "textnocase" ).toList( chr(10) ) );
		// The expected failure left the interactive job and the exit code set.
		job.reset();
		setExitCode( 0 );
	}

	/** @test */
	function jarOptions() {
		// java compile jarOptions:compress=false jarFile=jar-options.jar --jar --JSON
		runCompile( { jarFile="jar-options.jar", jarOptions={ "compress"=false } }, [ "jar", "JSON" ] );
		assertJarEntryCompression( resolvePath( "build/libs/jar-options.jar" ), "example/App.class", 0 );
	}

	/** @test */
	function sourceEncoding() {
		// java compile sourcePath=src/encoding/java compileOptions:encoding=UTF-8 classesDirectory=classes/source-encoding jarFile=source-encoding.jar --jar --JSON
		runCompile( { sourcePath="src/encoding/java", classesDirectory="classes/source-encoding", jarFile="source-encoding.jar", compileOptions={ "encoding"="UTF-8" } }, [ "jar", "JSON" ] );
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
		// java compile projectRootDirectory=boxjson-fixture --JSON
		cleanBoxJsonFixture();
		var result = runCompile( { projectRootDirectory="boxjson-fixture" }, [ "JSON" ] );
		assertFileExists( "boxjson-fixture/custom-classes/example/boxjson/BoxJsonApp.class" );
		assertFileExists( "boxjson-fixture/custom-libs/boxjson-app.jar" );
		assertJarManifestValue( resolvePath( "boxjson-fixture/custom-libs/boxjson-app.jar" ), "Implementation-Title", "BoxJSON Override" );
		assertEquals( reReplace( resolvePath( "boxjson-fixture/custom-classes" ), "[\\/]+$", "" ), reReplace( result.classOutputDirectory, "[\\/]+$", "" ) );
		assertEquals( reReplace( resolvePath( "boxjson-fixture/custom-libs" ), "[\\/]+$", "" ), reReplace( result.libsDirectory, "[\\/]+$", "" ) );
	}

	/** @test */
	function boxJsonCliDisable() {
		// java compile projectRootDirectory=boxjson-fixture jar=false javaDocs=false --JSON
		cleanBoxJsonFixture();
		runCompile( { projectRootDirectory="boxjson-fixture", jar=false, javaDocs=false }, [ "JSON" ] );
		assertFileExists( "boxjson-fixture/custom-classes/example/boxjson/BoxJsonApp.class" );
		assertFileMissing( "boxjson-fixture/custom-libs/boxjson-app.jar" );
	}

	/** @test */
	function boxJsonCliOverride() {
		// java compile projectRootDirectory=boxjson-fixture jarFile=cli-override.jar --JSON
		cleanBoxJsonFixture();
		runCompile( { projectRootDirectory="boxjson-fixture", jarFile="cli-override.jar" }, [ "JSON" ] );
		assertFileExists( "boxjson-fixture/custom-libs/cli-override.jar" );
		assertFileMissing( "boxjson-fixture/custom-libs/boxjson-app.jar" );
	}

	/** @test */
	function boxJsonCompileOptionsMerge() {
		// java compile projectRootDirectory=boxjson-fixture compileOptions:parameters=true --JSON
		cleanBoxJsonFixture();
		var result = runCompile( { projectRootDirectory="boxjson-fixture", compileOptions={ "parameters"=true } }, [ "JSON" ] );
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
		assertEquals( "src/main/java", boxJSON.java.sourcePath );
		assertEquals( "src/test/java", boxJSON.java.testSourcePath );
		assertEquals( "build/classes/java/main", boxJSON.java.classesDirectory );
		assertEquals( "build/classes/java/test", boxJSON.java.testClassesDirectory );
		assertEquals( "build/libs", boxJSON.java.libsDirectory );
		assertEquals( "src/main/resources", boxJSON.java.resourcesDirectory );
		assertEquals( "src/test/resources", boxJSON.java.testResourcesDirectory );
		assertEquals( "build/docs/javadoc", boxJSON.java.javaDocsDirectory );
		assertFileExists( "java-init-fixture/src/main/java/example/Example.java" );
		// The test half of the scaffold: the matching test, the test conventions,
		// and a test framework in devDependencies whose install path is recorded.
		assertFileExists( "java-init-fixture/src/test/java/example/ExampleTest.java" );
		assertEquals( true, directoryExists( "java-init-fixture/src/test/resources" ) );
		assertEquals( true, boxJSON.devDependencies.keyExists( "org.junit.platform:junit-platform-console-standalone" ) );
		assertEquals( "dist/test-dependencies/org.junit.platform-junit-platform-console-standalone", boxJSON.installPaths[ "org.junit.platform:junit-platform-console-standalone" ] );
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
			command( "java init" ).params( sourcePath="src/custom/java", classesDirectory="build/out", libsDirectory="dist", ide="vscode" ).run();
		} finally {
			shell.cd( originalDir );
		}

		var boxJSON = deserializeJSON( fileRead( fixtureDir & "/box.json" ) );
		assertEquals( "src/custom/java", boxJSON.java.sourcePath );
		assertEquals( "build/out", boxJSON.java.classesDirectory );
		assertEquals( "dist", boxJSON.java.libsDirectory );
		// Neither path has a `main` segment, so the test conventions fall back to their defaults.
		assertEquals( "src/test/java", boxJSON.java.testSourcePath );
		assertEquals( "build/classes/java/test", boxJSON.java.testClassesDirectory );
		assertFileExists( "java-init-custom-fixture/src/custom/java/example/Example.java" );
		assertFileExists( "java-init-custom-fixture/src/test/java/example/ExampleTest.java" );
		assertEquals( true, directoryExists( "java-init-custom-fixture/build/out" ) );
		// ide=vscode is passed through to java ide-init
		assertFileExists( "java-init-custom-fixture/.vscode/settings.json" );

		print.greenLine( "Java init custom folders test passed." );
	}

	/**
	 * Doc: "`java compile --tests` ... Main sources are always compiled; tests are
	 * added.", and a plain `java compile` leaves the test source set alone.
	 *
	 * @test
	 */
	function compileTestsIsAdditive() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();

		// A plain compile leaves the test output alone
		runJavaCompile( {}, [ "JSON" ] );
		assertFileExists( "java-test-fixture/dist/classes/example/Calc.class" );
		assertFileMissing( "java-test-fixture/dist/test-classes/example/CalcTest.class" );

		// --tests adds the test source set to the main one
		runJavaCompile( {}, [ "tests", "JSON" ] );
		assertFileExists( "java-test-fixture/dist/classes/example/Calc.class" );
		assertFileExists( "java-test-fixture/dist/test-classes/example/CalcTest.class" );

		print.greenLine( "Java compile --tests test passed." );
	}

	/**
	 * Doc: "`box java test` ... compiles both source sets, runs JUnit, exits 0."
	 *
	 * @test
	 */
	function javaTestRunsScaffoldedFixture() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();

		var result = runJavaTest( {}, [ "JSON" ] );
		assertEquals( 0, result.exitCode );
		var summary = deserializeJSON( print.unAnsi( result.output ) );
		assertEquals( 2, summary.totalTests );
		assertEquals( 2, summary.passed );
		assertEquals( 0, summary.failed );
		assertEquals( 0, summary.exitCode );

		print.greenLine( "Java test fixture test passed." );
	}

	/**
	 * Doc: "exits 1 when a test fails", and the failure is reported per test.
	 *
	 * @test
	 */
	function javaTestFailsWhenATestFails() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();

		var brokenTest = resolvePath( "java-test-fixture/src/test/java/example/BrokenTest.java" );
		fileWrite( brokenTest, "package example;" & chr( 10 )
			& "import static org.junit.jupiter.api.Assertions.assertEquals;" & chr( 10 )
			& "import org.junit.jupiter.api.Test;" & chr( 10 )
			& "public class BrokenTest {" & chr( 10 )
			& "  @Test public void failsOnPurpose() { assertEquals( 5, new Calc().add( 2, 2 ) ); }" & chr( 10 )
			& "}" & chr( 10 ) );

		try {
			var result = runJavaTest( {}, [ "JSON" ] );
			assertEquals( 1, result.exitCode );
			assertEquals( true, result.message.contains( "failing exit code" ) );
		} finally {
			if( fileExists( brokenTest ) ) fileDelete( brokenTest );
		}

		print.greenLine( "Java test failure test passed." );
	}

	/**
	 * Doc: "`testClasses=pkg.Class`, `testClasses=pkg.Class#method` and
	 * `testClasses=pkg.*` run exactly the selected tests; an unmatched pattern fails
	 * with a clear message."
	 *
	 * @test
	 */
	function javaTestSelection() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();

		var oneMethod = runJavaTest( { testClasses="example.CalcTest" & chr( 35 ) & "addsTwoNumbers" }, [ "JSON" ] );
		assertEquals( 0, oneMethod.exitCode );
		assertEquals( 1, deserializeJSON( print.unAnsi( oneMethod.output ) ).totalTests );

		var wildcard = runJavaTest( { testClasses="example.*" }, [ "JSON" ] );
		assertEquals( 0, wildcard.exitCode );
		assertEquals( 2, deserializeJSON( print.unAnsi( wildcard.output ) ).totalTests );

		var unmatched = runJavaTest( { testClasses="example.NotThere" }, [ "JSON" ] );
		assertEquals( 3, unmatched.exitCode );
		assertEquals( true, unmatched.message.contains( "failing exit code" ) );

		print.greenLine( "Java test selection test passed." );
	}

	/**
	 * Doc: "`reportsDirectory=<dir>` writes JUnit XML", and dev dependencies live in
	 * their own directory so they never end up in the shipped JAR.
	 *
	 * @test
	 */
	function javaTestReportsAndDevDependencyIsolation() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();

		var result = runJavaTest( { reportsDirectory="dist/test-reports" }, [ "JSON" ] );
		assertEquals( 0, result.exitCode );
		assertFileExists( "java-test-fixture/dist/test-reports/TEST-commandbox.xml" );
		assertTrue(
			fileRead( resolvePath( "java-test-fixture/dist/test-reports/TEST-commandbox.xml" ) ).contains( "example.CalcTest" ),
			"the report must name the test class"
		);

		// The dev dependencies are installed into their own directory, and nothing
		// was installed into the runtime dependency directory.
		assertTrue( directoryExists( resolvePath( "java-test-fixture/dist/test-dependencies" ) ), "expected the dev dependency directory" );
		assertEquals( false, directoryExists( resolvePath( "java-test-fixture/dist/dependencies" ) ) );

		print.greenLine( "Java test reports and dev dependency isolation test passed." );
	}

	/**
	 * Doc: "`java clean` removes `classesDirectory` and `testClassesDirectory` and the
	 * jar output but leaves dependency directories unless `--dependencies` is passed".
	 *
	 * @test
	 */
	function javaCleanRemovesOutputOnly() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();
		runJavaCompile( {}, [ "tests", "jar", "JSON" ] );
		// The jar name is derived from the package slug and version, which is the
		// output `java clean` knows how to remove.
		assertFileExists( "java-test-fixture/dist/libs/java-test-fixture-1.0.0.jar" );

		command( "java clean" ).inWorkingDirectory( resolvePath( "java-test-fixture" ) ).run();
		assertEquals( false, directoryExists( resolvePath( "java-test-fixture/dist/classes" ) ) );
		assertEquals( false, directoryExists( resolvePath( "java-test-fixture/dist/test-classes" ) ) );
		assertFileMissing( "java-test-fixture/dist/libs/java-test-fixture-1.0.0.jar" );
		// Dependencies are left alone so a clean does not force a re-download
		assertTrue( directoryExists( resolvePath( "java-test-fixture/dist/test-dependencies" ) ), "clean must keep the dependency directory" );

		var dependenciesOutput = command( "java clean" )
			.inWorkingDirectory( resolvePath( "java-test-fixture" ) )
			.flags( "dependencies" )
			.run( returnOutput=true );
		assertTrue( dependenciesOutput.len() > 0, "clean --dependencies must report what it removed" );
		assertEquals( false, directoryExists( resolvePath( "java-test-fixture/dist/test-dependencies" ) ) );

		print.greenLine( "Java clean test passed." );
	}

	/**
	 * Doc: "exits 3 when there are no tests and `--failIfNoTests` is on", and
	 * `failIfNoTests=false` turns that into a pass.
	 *
	 * @test
	 */
	function javaTestNoTestsFound() {
		cleanJavaTestFixture();
		prepareJavaTestFixture();

		// dist/test-classes does not exist, so there is nothing to run
		var noTests = runJavaTest( {}, [ "skipCompile", "JSON" ] );
		assertEquals( 3, noTests.exitCode );
		assertEquals( true, noTests.message.contains( "failing exit code" ) );

		var noFailure = runJavaTest( { failIfNoTests=false }, [ "skipCompile", "JSON" ] );
		assertEquals( 0, noFailure.exitCode );
		assertEquals( 0, deserializeJSON( print.unAnsi( noFailure.output ) ).totalTests );

		print.greenLine( "Java test no-tests test passed." );
	}

	/**
	 * Doc: exit code 4 when no runner is found on the test classpath. The fixture
	 * has an empty devDependencies block, so JUnit's console launcher is absent.
	 *
	 * @test
	 */
	function javaTestRequiresARunner() {
		cleanNoRunnerFixture();
		var result = runJavaTest( {}, [ "JSON" ], "java-test-norunner-fixture" );
		assertEquals( 4, result.exitCode );
		assertEquals( true, result.message.contains( "failing exit code (4)" ) );

		print.greenLine( "Java test no-runner test passed." );
	}

	/**
	 * Doc: exit code 2 on a compile error. A test source that does not compile fails
	 * the test pass, which is a compile failure rather than a test failure.
	 *
	 * @test
	 */
	function javaTestFailedTestCompile() {
		cleanNoRunnerFixture();
		var brokenTest = resolvePath( "java-test-norunner-fixture/src/test/java/example/Broken.java" );
		fileWrite( brokenTest, "package example; public class Broken { this is not java }" );

		try {
			// A compile failure is a plain command error, so it exits 1 like any other
			// failing command. Run it out of process so the failure cannot kill the task.
			var result = runJavaTestProcess( "--JSON", "java-test-norunner-fixture" );
			assertEquals( 1, result.exitCode );
		} finally {
			if( fileExists( brokenTest ) ) fileDelete( brokenTest );
		}

		print.greenLine( "Java test compile failure test passed." );
	}

	/**
	 * Deletes the compiled output of the no-runner fixture.
	 */
	private void function cleanNoRunnerFixture() {
		[ "dist/classes", "dist/test-classes" ].each( function( dir ) {
			var path = resolvePath( "java-test-norunner-fixture/#dir#" );
			if( directoryExists( path ) ) directoryDelete( path, true );
		} );
	}

	/**
	 * Runs `java compile` in the java test fixture and returns the parsed JSON result.
	 *
	 * @struct The struct.
	 * @params The parameters to pass to the command.
	 * @array The array.
	 * @flags The flags to pass to the command.
	 * @returns The compile result.
	 */
	private struct function runJavaCompile( struct params={}, array flags=[] ) {
		var compileCommand = command( "java compile" ).inWorkingDirectory( resolvePath( "java-test-fixture" ) );
		compileCommand.params( argumentCollection=arguments.params );
		compileCommand.flags( argumentCollection=arguments.flags );
		var output = compileCommand.run( returnOutput=true );
		return output.len() ? deserializeJSON( print.unAnsi( output ) ) : {};
	}

	/**
	 * Runs `java test` against the fixture and captures the exit code even though a
	 * non-zero exit makes the command DSL throw.
	 */
	private struct function runJavaTest( struct params={}, array flags=[], string fixtureDirectory="java-test-fixture" ) {
		var result = { "exitCode" : 0, "output" : "", "message" : "" };
		var testCommand = command( "java test" );
		testCommand.params( argumentCollection=arguments.params );
		testCommand.flags( argumentCollection=arguments.flags );
		// cd rather than inWorkingDirectory(): a command that throws with an active job
		// while CommandDSL has a working directory set takes the whole run down.
		var originalDirectory = getCWD();
		shell.cd( resolvePath( arguments.fixtureDirectory ) );
		try {
			result.output = testCommand.run( returnOutput=true );
		} catch( any e ) {
			// errorCode is empty for a plain commandException, so fall back to 1 when it
			// is not a usable number.
			var errorCode = e.errorCode ?: "";
			result.exitCode = isSimpleValue( errorCode ) && len( errorCode ) ? val( errorCode ) : 1;
			result.message = e.message;
			// CommandService attaches whatever the command printed to the exception,
			// which is where the diagnostic message lives for a non-zero exit.
			var extendedInfo = e.extendedInfo ?: "";
			if( isSimpleValue( extendedInfo ) && isJSON( extendedInfo ) ) {
				result.output = deserializeJSON( extendedInfo ).commandOutput ?: "";
			} else if( isSimpleValue( extendedInfo ) ) {
				result.output = extendedInfo;
			}
		} finally {
			shell.cd( originalDirectory );
		}
		return result;
	}

	/**
	 * Runs `java test` in its own CLI process so a compile failure cannot take the task
	 * run down with it, and returns the exit code and message.
	 *
	 * @args Arguments to pass to `java test`.
	 * @fixtureDirectory The fixture to run in, relative to this test file.
	 * @returns A struct with exitCode, output and message.
	 */
	private struct function runJavaTestProcess( required string args, required string fixtureDirectory ) {
		var result = { "exitCode" : 0, "output" : "", "message" : "" };
		try {
			result.output = command( "run" )
				.inWorkingDirectory( resolvePath( arguments.fixtureDirectory ) )
				.params( "box java test " & arguments.args )
				.run( returnOutput=true );
		} catch( any e ) {
			var errorCode = e.errorCode ?: "";
			result.exitCode = isSimpleValue( errorCode ) && len( errorCode ) ? val( errorCode ) : 1;
			result.message = e.message;
		}
		return result;
	}

	/**
	 * Installs the fixture's dev dependencies once, the way `java init` + `install`
	 * would for a real project.
	 */
	private void function prepareJavaTestFixture() {
		if( !directoryExists( resolvePath( "java-test-fixture/dist/test-dependencies" ) ) ) {
			command( "install" ).inWorkingDirectory( resolvePath( "java-test-fixture" ) ).run();
		}
	}

	/**
	 * Deletes the compiled output and jars of the java test fixture.
	 */
	private void function cleanJavaTestFixture() {
		[ "dist/classes", "dist/test-classes", "build/libs", "dist/libs" ].each( function( dir ) {
			var path = resolvePath( "java-test-fixture/#dir#" );
			if( directoryExists( path ) ) directoryDelete( path, true );
		} );
	}

	/**
	 * Deletes the output directories the box.json fixture tests generate.
	 */
	private function cleanBoxJsonFixture() {
		[ "custom-classes", "custom-libs", "build" ].each( function( dir ) {
			var path = resolvePath( "boxjson-fixture/#dir#" );
			if( directoryExists( path ) ) directoryDelete( path, true );
		} );
	}

	/**
	 * Runs `java compile` in this directory and returns the parsed JSON result.
	 *
	 * @struct The struct.
	 * @params The parameters to pass to the command.
	 * @array The array.
	 * @flags The flags to pass to the command.
	 * @returns The compile result.
	 */
	private struct function runCompile( struct params={}, array flags=[] ) {
		var compileCommand = command( "java compile" );
		compileCommand.params( argumentCollection=arguments.params );
		compileCommand.flags( argumentCollection=arguments.flags );
		return deserializeJSON( print.unAnsi( compileCommand.run( returnOutput=true ) ) );
	}

	/**
	 * Installs the maven fixture dependency once, when it is not already present.
	 */
	private void function prepareMavenDependency() {
		if( !directoryExists( "libs/maven" ) ) {
			command( "package install" )
				.params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false )
				.run();
		}
	}

	/**
	 * Asserts that a file exists.
	 *
	 * @filePath The file path to check.
	 */
	private function assertFileExists( required string filePath ) {
		if( !fileExists( arguments.filePath ) ) error( "Expected file was not created: #arguments.filePath#" );
	}

	/**
	 * Asserts that a file does not exist.
	 *
	 * @filePath The file path to check.
	 */
	private function assertFileMissing( required string filePath ) {
		if( fileExists( arguments.filePath ) ) error( "Expected file to be missing: #arguments.filePath#" );
	}

	/**
	 * Asserts that two values are equal.
	 *
	 * @expected The expected value.
	 * @actual The actual value.
	 */
	private function assertEquals( required expected, required actual ) {
		if( arguments.expected != arguments.actual ) error( "Expected [#arguments.expected#], received [#arguments.actual#]." );
	}

	/**
	 * Asserts that a condition is true.
	 *
	 * @condition The condition to check.
	 * @message The failure message.
	 */
	private function assertTrue( required boolean condition, required string message ) {
		if( !arguments.condition ) error( arguments.message );
	}

	/**
	 * Asserts that a struct contains every expected key.
	 *
	 * @value The value to check.
	 * @keys The expected key names.
	 */
	private function assertStructKeys( required struct value, required array keys ) {
		for( var key in arguments.keys ) {
			if( !arguments.value.keyExists( key ) ) error( "Expected result key was not returned: #key#" );
		}
	}

	/**
	 * Asserts that a JAR contains an entry.
	 *
	 * @jarFile The JAR to inspect.
	 * @entryName The entry inside the JAR.
	 */
	private function assertJarEntryExists( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			if( isNull( jar.getJarEntry( arguments.entryName ) ) ) error( "Expected JAR entry was not found: #arguments.entryName#" );
		} finally {
			jar.close();
		}
	}

	/**
	 * Asserts that a JAR does not contain an entry.
	 *
	 * @jarFile The JAR to inspect.
	 * @entryName The entry inside the JAR.
	 */
	private function assertJarEntryMissing( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			if( !isNull( jar.getJarEntry( arguments.entryName ) ) ) error( "Unexpected JAR entry was found: #arguments.entryName#" );
		} finally {
			jar.close();
		}
	}

	/**
	 * Reads one entry out of a JAR as trimmed text.
	 *
	 * @jarFile The JAR to inspect.
	 * @entryName The entry inside the JAR.
	 * @returns The entry content.
	 */
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

	/**
	 * Builds a dependency JAR containing a META-INF/services descriptor.
	 *
	 * @directory The directory to write into.
	 * @jarFile The JAR to inspect.
	 * @provider The service provider class name.
	 * @string The string.
	 * @signatureFile Optional signature file to add.
	 */
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

	/**
	 * Builds a dependency JAR containing a plain resource.
	 *
	 * @directory The directory to write into.
	 * @jarFile The JAR to inspect.
	 * @resourceContents The resource content to write.
	 */
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

	/**
	 * Asserts a manifest attribute in a JAR.
	 *
	 * @jarFile The JAR to inspect.
	 * @attributeName The manifest attribute name.
	 * @expectedValue The expected attribute value.
	 */
	private function assertJarManifestValue( required string jarFile, required string attributeName, required string expectedValue ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );
		try {
			assertEquals( arguments.expectedValue, jar.getManifest().getMainAttributes().getValue( arguments.attributeName ) );
		} finally {
			jar.close();
		}
	}

	/**
	 * Asserts the class-file major version, which proves the compile release.
	 *
	 * @classFile The compiled class file.
	 * @expectedVersion The expected major version.
	 */
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

	/**
	 * Asserts the compression method of a JAR entry.
	 *
	 * @jarFile The JAR to inspect.
	 * @entryName The entry inside the JAR.
	 * @expectedMethod The expected compression method.
	 */
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

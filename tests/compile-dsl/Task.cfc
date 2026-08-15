component {

	function run( boolean verbose=false ) {
		this.$bx.meta.functions
			.filter( function( functionMetadata ) {
				return functionMetadata.annotations.keyExists( "test" );
			} )
			.each( function( functionMetadata ) {
				print.line()
					.yellowLine( "── Running #functionMetadata.name# ──" )
					.toConsole();
				try {
					invoke( this, functionMetadata.name, { "verbose" : verbose } );
					print.greenLine( "✓ #functionMetadata.name# passed" ).toConsole();
				} catch( any e ) {
					print.redLine( "✗ #functionMetadata.name# failed" )
						.redLine( "  #e.message#" )
						.toConsole();
				}
			} );
		print.line().toConsole();
	}

	/**
	 * @test
	 */
	function thinJar( boolean verbose=false ) {
		var classesDirectory = resolvePath( "build/classes/java/main" );
		var jarFile = resolvePath( "build/libs/compile-dsl.jar" );

		if( directoryExists( resolvePath( "build" ) ) ) {
			directoryDelete( resolvePath( "build" ), true );
		}

		var result = compile()
			.setVerbose( arguments.verbose )
			.toJar()
			.run();

		assertFileExists( classesDirectory & "/example/App.class" );
		assertFileExists( jarFile );
		assertFileExists( result.jarPath );

		classLoad( jarFile );
		var app = createObject( "java", "example.App" ).init();
		assertEquals( "thin jar works", app.message() );

		print.greenLine( "Thin-JAR test passed." );
	}

	/**
	 * @test
	 */
	function resultMetadata( boolean verbose=false ) {
		var result = compile()
			.setVerbose( arguments.verbose )
			.run();

		assertStructKeys(
			result,
			[
				"projectRoot",
				"jdkBinDirectory",
				"sourcePaths",
				"classOutputDirectory",
				"libsDirectory",
				"jarPath",
				"javaDocsPath",
				"resourcePath",
				"classPaths",
				"fatJarPaths",
				"compileOptions",
				"jarOptions",
				"encoding",
				"manifest"
			]
		);
		assertEquals( resolvePath( "" ), result.projectRoot );
		assertEquals( "", result.jarPath );
		assertEquals( "", result.javaDocsPath );
		
		print.line(result).toConsole();
		print.greenLine( "Result metadata test passed." );
	}

	/**
	 * @test
	 */
	function nonStandardSourcePath( boolean verbose=false ) {
		var classesDirectory = resolvePath( "build/classes/java/main" );
		var jarFile = resolvePath( "build/libs/non-standard-source.jar" );

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/custom/java" )
			.toJar( "non-standard-source.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/custom/SourcePathApp.class" );
		assertFileExists( jarFile );

		classLoad( jarFile );
		var app = createObject( "java", "example.custom.SourcePathApp" ).init();
		assertEquals( "non-standard source works", app.message() );

		print.greenLine( "Non-standard source-path test passed." );
	}

	/**
	 * @test
	 */
	function multipleSourcePaths( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/multiple-sources" );
		var jarFile = resolvePath( "build/libs/multiple-sources.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( [ "src/main/java", "src/custom/java" ] )
			.toClasses( "classes/multiple-sources" )
			.toJar( "multiple-sources.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/App.class" );
		assertFileExists( classesDirectory & "/example/custom/SourcePathApp.class" );
		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "example/App.class" );
		assertJarEntryExists( jarFile, "example/custom/SourcePathApp.class" );

		classLoad( jarFile );
		assertEquals( "thin jar works", createObject( "java", "example.App" ).init().message() );
		assertEquals(
			"non-standard source works",
			createObject( "java", "example.custom.SourcePathApp" ).init().message()
		);

		print.greenLine( "Multiple source-path test passed." );
	}

	/**
	 * @test
	 */
	function sourceGlob( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/source-glob" );
		var jarFile = resolvePath( "build/libs/source-glob.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/custom/java/**/*.java" )
			.toClasses( "classes/source-glob" )
			.toJar( "source-glob.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/custom/SourcePathApp.class" );
		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "example/custom/SourcePathApp.class" );

		classLoad( jarFile );
		var app = createObject( "java", "example.custom.SourcePathApp" ).init();
		assertEquals( "non-standard source works", app.message() );

		print.greenLine( "Source glob test passed." );
	}

	/**
	 * @test
	 */
	function defaultResources( boolean verbose=false ) {
		var jarFile = resolvePath( "build/libs/default-resources.jar" );

		compile()
			.setVerbose( arguments.verbose )
			.toJar( "default-resources.jar" )
			.run();

		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "default-resource.txt" );
		assertJarEntryExists( jarFile, "nested/default-nested-resource.txt" );

		print.greenLine( "Default resources test passed." );
	}

	/**
	 * @test
	 */
	function packageMetadata( boolean verbose=false ) {
		var packageRoot = resolvePath( "package-fixture" );
		var jarFile = resolvePath( "package-fixture/build/libs/compile-dsl-package-1.2.3.jar" );

		if( directoryExists( packageRoot & "/build" ) ) {
			directoryDelete( packageRoot & "/build", true );
		}

		var result = getInstance( "compileDSL" )
			.projectRoot( packageRoot )
			.setVerbose( arguments.verbose )
			.toJar()
			.run();

		assertFileExists( jarFile );
		assertFileExists( result.jarPath );
		assertJarManifestValue( jarFile, "Bundle-Name", "Compile DSL Package" );
		assertJarManifestValue( jarFile, "Bundle-SymbolicName", "compile-dsl-package" );
		assertJarManifestValue( jarFile, "Bundle-Version", "1.2.3" );
		assertJarManifestValue( jarFile, "Implementation-Title", "Package Manifest Override" );

		print.greenLine( "Package metadata test passed." );
	}

	/**
	 * @test
	 */
	function customClassOutput( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/custom-output" );
		var jarFile = resolvePath( "build/libs/custom-class-output.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.toClasses( "classes/custom-output" )
			.toJar( "custom-class-output.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/App.class" );
		assertFileExists( jarFile );

		classLoad( jarFile );
		var app = createObject( "java", "example.App" ).init();
		assertEquals( "thin jar works", app.message() );

		print.greenLine( "Custom class-output test passed." );
	}

	/**
	 * @test
	 */
	function customLibraryDirectory( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/custom-libs" );
		var jarFile = resolvePath( "custom-libs/custom-library-directory.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.toClasses( "classes/custom-libs" )
			.libsDir( "custom-libs" )
			.toJar( "custom-library-directory.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/App.class" );
		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "example/App.class" );

		print.greenLine( "Custom library-directory test passed." );
	}

	/**
	 * @test
	 */
	function resources( boolean verbose=false ) {
		var jarFile = resolvePath( "build/libs/resources.jar" );

		compile()
			.setVerbose( arguments.verbose )
			.withResources( "src/resources-test" )
			.toJar( "resources.jar" )
			.run();

		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "message.txt" );

		print.greenLine( "Resources test passed." );
	}

	/**
	 * @test
	 */
	function customManifest( boolean verbose=false ) {
		var jarFile = resolvePath( "build/libs/custom-manifest.jar" );

		compile()
			.setVerbose( arguments.verbose )
			.manifest( { "Implementation-Title" : "Compile DSL Test" } )
			.toJar( "custom-manifest.jar" )
			.run();

		assertFileExists( jarFile );
		assertJarManifestValue( jarFile, "Implementation-Title", "Compile DSL Test" );

		print.greenLine( "Custom manifest test passed." );
	}

	/**
	 * @test
	 */
	function compilerOptions( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/compiler-options" );
		var classFile = classesDirectory & "/example/App.class";
		var jarFile = resolvePath( "build/libs/compiler-options.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.toClasses( "classes/compiler-options" )
			.compileOptions( {
				"release" : 8,
				"debug" : [ "lines", "source" ],
				"parameters" : true,
				"deprecation" : true,
				"lint" : [ "deprecation" ],
				"maxErrors" : 10,
				"maxWarnings" : 10
			} )
			.toJar( "compiler-options.jar" )
			.run();

		assertFileExists( classFile );
		assertFileExists( jarFile );
		assertClassMajorVersion( classFile, 52 );

		print.greenLine( "Compiler options test passed." );
	}

	/**
	 * @test
	 */
	function jarOptionValues( boolean verbose=false ) {
		var jarFile = resolvePath( "build/libs/jar-option-values.jar" );

		compile()
			.setVerbose( arguments.verbose )
			.jarOptions( {
				"compress" : false,
				"mainClass" : "example.App",
				"date" : now()
			} )
			// A custom manifest combined with jar options exercises the
			// --create --file=... --manifest=... branch of buildJar().
			.manifest( {
				"Implementation-Title" : "JAR Option Values"
			} )
			.toJar( "jar-option-values.jar" )
			.run();

		assertFileExists( jarFile );
		assertJarEntryCompression( jarFile, "example/App.class", 0 );
		assertJarManifestValue( jarFile, "Main-Class", "example.App" );
		assertJarManifestValue( jarFile, "Implementation-Title", "JAR Option Values" );

		print.greenLine( "JAR option values test passed." );
	}

	/**
	 * @test
	 */
	function classPath( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/classpath" );
		var mavenDirectory = resolvePath( "libs/maven" );
		var jarFile = resolvePath( "build/libs/classpath.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}
		if( directoryExists( mavenDirectory ) ) {
			directoryDelete( mavenDirectory, true );
		}

		command( "package install" )
			.params(
				ID="maven:org.apache.commons:commons-lang3:3.14.0",
				directory="libs/maven",
				save=false,
				lock=false
			)
			.run();

		var dependencyJars = directoryList( mavenDirectory, true, "array", "*.jar" );
		if( dependencyJars.len() != 1 ) {
			error( "Expected one Maven dependency JAR, found #dependencyJars.len()#." );
		}
		var dependencyJar = dependencyJars.first();

		var result = compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/classpath/java" )
			.withClassPath( "libs/maven" )
			.toClasses( "classes/classpath" )
			.toJar( "classpath.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/classpath/ClasspathApp.class" );
		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "example/classpath/ClasspathApp.class" );
		assertFileExists( result.jarPath );
		assertEquals( reReplace( classesDirectory, "[\\/]+$", "" ), reReplace( result.classOutputDirectory, "[\\/]+$", "" ) );
		assertEquals( dependencyJar, result.classPaths.first() );
		assertEquals( resolvePath( "src/main/resources" ), result.resourcePath );
		assertEquals( "", result.compileOptions );
		assertEquals( "", result.jarOptions );
		assertEquals( "", result.encoding );

		classLoad( [ dependencyJar, jarFile ] );
		var app = createObject( "java", "example.classpath.ClasspathApp" ).init();
		assertEquals( "classpath: Apache commons", app.message() );

		print.greenLine( "Classpath test passed." );
	}

	/**
	 * @test
	 */
	function multipleClassPaths( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/multiple-classpaths" );
		var mavenDirectory = resolvePath( "libs/maven" );
		var localDependencyJar = resolvePath( "build/libs/compile-dsl.jar" );
		var jarFile = resolvePath( "build/libs/multiple-classpaths.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}
		if( !fileExists( localDependencyJar ) ) thinJar( arguments.verbose );
		if( !directoryExists( mavenDirectory ) ) {
			command( "package install" )
				.params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false )
				.run();
		}

		var mavenDependencyJars = directoryList( mavenDirectory, true, "array", "*.jar" );
		if( mavenDependencyJars.len() != 1 ) {
			error( "Expected one Maven dependency JAR, found #mavenDependencyJars.len()#." );
		}
		var mavenDependencyJar = mavenDependencyJars.first();

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/multiple-classpath/java" )
			.withClassPath( [ localDependencyJar, "libs/maven" ] )
			.toClasses( "classes/multiple-classpaths" )
			.toJar( "multiple-classpaths.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/multipleclasspath/MultiClasspathApp.class" );
		assertFileExists( jarFile );

		classLoad( [ localDependencyJar, mavenDependencyJar, jarFile ] );
		var app = createObject( "java", "example.multipleclasspath.MultiClasspathApp" ).init();
		assertEquals( "multiple: thin jar works / Apache commons", app.message() );

		print.greenLine( "Multiple classpath test passed." );
	}

	/**
	 * @test
	 */
	function classPathList( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/classpath-list" );
		var mavenDirectory = resolvePath( "libs/maven" );
		var jarFile = resolvePath( "build/libs/classpath-list.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/multiple-classpath/java" )
			.withClassPath( "build/libs,libs/maven" )
			.toClasses( "classes/classpath-list" )
			.toJar( "classpath-list.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/multipleclasspath/MultiClasspathApp.class" );
		assertFileExists( jarFile );

		print.greenLine( "Classpath list test passed." );
	}

	/**
	 * @test
	 */
	function javaDocs( boolean verbose=false ) {
		var javaDocsDirectory = resolvePath( "build/docs/javadoc" );

		if( directoryExists( javaDocsDirectory ) ) {
			directoryDelete( javaDocsDirectory, true );
		}

		var result = compile()
			.setVerbose( arguments.verbose )
			.withJavaDocs()
			.run();

		assertFileExists( javaDocsDirectory & "/index.html" );
		assertEquals(
			reReplace( javaDocsDirectory, "[\\/]+$", "" ),
			reReplace( result.javaDocsPath, "[\\/]+$", "" )
		);

		print.greenLine( "Javadocs test passed." );
	}

	/**
	 * @test
	 */
	function fatJar( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/fat-jar" );
		var mavenDirectory = resolvePath( "libs/maven" );
		var localDependencyJar = resolvePath( "build/libs/compile-dsl.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}
		if( !fileExists( localDependencyJar ) ) thinJar( arguments.verbose );
		if( !directoryExists( mavenDirectory ) ) {
			command( "package install" )
				.params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false )
				.run();
		}

		var dependencyJars = directoryList( mavenDirectory, true, "array", "*.jar" );
		if( dependencyJars.len() != 1 ) {
			error( "Expected one Maven dependency JAR, found #dependencyJars.len()#." );
		}
		var dependencyJar = dependencyJars.first();

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/multiple-classpath/java" )
			.withClassPath( [ localDependencyJar, "libs/maven" ] )
			.toClasses( "classes/fat-jar" )
			.toJar( "fat-jar-src.jar" )
			.toFatJar( "fat-jar.jar", [ localDependencyJar, dependencyJar ] )
			.run();

		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "example/multipleclasspath/MultiClasspathApp.class" );
		assertJarEntryExists( jarFile, "example/App.class" );
		assertJarEntryExists( jarFile, "org/apache/commons/lang3/StringUtils.class" );

		classLoad( jarFile );
		var app = createObject( "java", "example.multipleclasspath.MultiClasspathApp" ).init();
		assertEquals( "multiple: thin jar works / Apache commons", app.message() );

		print.greenLine( "Fat-JAR test passed." );
	}

	/**
	 * @test
	 */
	function thinAndFatJar( boolean verbose=false ) {
		var mavenDirectory = resolvePath( "libs/maven" );
		var localDependencyJar = resolvePath( "build/libs/compile-dsl.jar" );
		var thinJarFile = resolvePath( "build/libs/thin-and-fat.jar" );
		var fatJarFile = resolvePath( "build/libs/thin-and-fat-all.jar" );

		if( !fileExists( localDependencyJar ) ) thinJar( arguments.verbose );
		if( !directoryExists( mavenDirectory ) ) {
			command( "package install" )
				.params( ID="maven:org.apache.commons:commons-lang3:3.14.0", directory="libs/maven", save=false, lock=false )
				.run();
		}

		var dependencyJar = directoryList( mavenDirectory, true, "array", "*.jar" ).first();
		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/multiple-classpath/java" )
			.withClassPath( [ localDependencyJar, "libs/maven" ] )
			.toJar( "thin-and-fat.jar" )
			.toFatJar( "thin-and-fat-all.jar", [ localDependencyJar, dependencyJar ] )
			.run();

		assertFileExists( thinJarFile );
		assertFileExists( fatJarFile );
		assertJarEntryMissing( thinJarFile, "org/apache/commons/lang3/StringUtils.class" );
		assertJarEntryExists( fatJarFile, "org/apache/commons/lang3/StringUtils.class" );

		print.greenLine( "Thin and fat JAR test passed." );
	}

	/**
	 * @test
	 */
	function fatJarServiceDescriptors( boolean verbose=false ) {
		var serviceOneDirectory = resolvePath( "fat-jar-services/one" );
		var serviceTwoDirectory = resolvePath( "fat-jar-services/two" );
		var serviceOneJar = resolvePath( "libs/fat-jar-service-one.jar" );
		var serviceTwoJar = resolvePath( "libs/fat-jar-service-two.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-services.jar" );

		if( fileExists( jarFile ) ) {
			fileDelete( jarFile );
		}
		createServiceDependencyJar(
			serviceOneDirectory,
			serviceOneJar,
			"example.provider.First",
			"DEPENDENCY.SF"
		);
		createServiceDependencyJar(
			serviceTwoDirectory,
			serviceTwoJar,
			"example.provider.Second"
		);

		compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-services-src.jar" )
			.toFatJar( "fat-jar-services.jar", [ serviceOneJar, serviceTwoJar ] )
			.run();

		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "META-INF/services/example.Service" );
		assertJarEntryMissing( jarFile, "META-INF/DEPENDENCY.SF" );
		assertEquals(
			"example.provider.First#chr(10)#example.provider.Second",
			readJarEntry( jarFile, "META-INF/services/example.Service" )
		);

		print.greenLine( "Fat-JAR service descriptor test passed." );
	}

	/**
	 * @test
	 */
	function fatJarDuplicateResources( boolean verbose=false ) {
		var firstDirectory = resolvePath( "fat-jar-duplicates/first" );
		var secondDirectory = resolvePath( "fat-jar-duplicates/second" );
		var firstJar = resolvePath( "libs/fat-jar-duplicate-first.jar" );
		var secondJar = resolvePath( "libs/fat-jar-duplicate-second.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-duplicates.jar" );

		createResourceDependencyJar( firstDirectory, firstJar, "first dependency" );
		createResourceDependencyJar( secondDirectory, secondJar, "second dependency" );

		compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-duplicates-src.jar" )
			.toFatJar( "fat-jar-duplicates.jar", [ firstJar, secondJar ] )
			.run();

		assertFileExists( jarFile );
		assertEquals( "second dependency", readJarEntry( jarFile, "duplicate-resource.txt" ) );

		print.greenLine( "Fat-JAR duplicate resource test passed." );
	}

	/**
	 * @test
	 */
	function fatJarMergeOptions( boolean verbose=false ) {
		var serviceOneDirectory = resolvePath( "fat-jar-options/one" );
		var serviceTwoDirectory = resolvePath( "fat-jar-options/two" );
		var serviceOneJar = resolvePath( "libs/fat-jar-options-one.jar" );
		var serviceTwoJar = resolvePath( "libs/fat-jar-options-two.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-options.jar" );

		createServiceDependencyJar(
			serviceOneDirectory,
			serviceOneJar,
			"example.provider.First",
			"DEPENDENCY.SF"
		);
		createServiceDependencyJar(
			serviceTwoDirectory,
			serviceTwoJar,
			"example.provider.Second"
		);

		compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-options-src.jar" )
			.toFatJar(
				"fat-jar-options.jar",
				[ serviceOneJar, serviceTwoJar ],
				{
					"mergeServiceDescriptors" : false,
					"excludeSignatures"       : false
				}
			)
			.run();

		assertJarEntryExists( jarFile, "META-INF/DEPENDENCY.SF" );
		assertEquals( "example.provider.Second", readJarEntry( jarFile, "META-INF/services/example.Service" ) );

		print.greenLine( "Fat-JAR merge options test passed." );
	}

	/**
	 * @test
	 */
	function fatJarDuplicatePolicies( boolean verbose=false ) {
		var firstDirectory = resolvePath( "fat-jar-policies/first" );
		var secondDirectory = resolvePath( "fat-jar-policies/second" );
		var firstJar = resolvePath( "libs/fat-jar-policy-first.jar" );
		var secondJar = resolvePath( "libs/fat-jar-policy-second.jar" );
		var firstJarFile = resolvePath( "build/libs/fat-jar-policy-first-wins.jar" );
		var errorJarFile = resolvePath( "build/libs/fat-jar-policy-error.jar" );
		var duplicateFailed = false;

		createResourceDependencyJar( firstDirectory, firstJar, "first dependency" );
		createResourceDependencyJar( secondDirectory, secondJar, "second dependency" );

		compile()
			.setVerbose( arguments.verbose )
			.configureFatJar( { "duplicatePolicy" : "first" } )
			.toJar( "fat-jar-policy-first-wins-src.jar" )
			.toFatJar(
				"fat-jar-policy-first-wins.jar",
				[ firstJar, secondJar ]
			)
			.run();
		assertEquals( "first dependency", readJarEntry( firstJarFile, "duplicate-resource.txt" ) );

		try {
			compile()
				.setVerbose( arguments.verbose )
				.toJar( "fat-jar-policy-error-src.jar" )
				.toFatJar(
					"fat-jar-policy-error.jar",
					[ firstJar, secondJar ],
					{ "duplicatePolicy" : "error" }
				)
				.run();
		} catch( any e ) {
			duplicateFailed = true;
		}

		assertEquals( true, duplicateFailed );
		job.reset();
		setExitCode( 0 );

		print.greenLine( "Fat-JAR duplicate policies test passed." );
	}

	/**
	 * @test
	 */
	function failedCompileCleanup( boolean verbose=false ) {
		var tempDirectory = getInstance( "tempDir@constants" );
		var beforeTempFiles = directoryList( tempDirectory, false, "array", "temp*.txt" );
		var compileFailed = false;

		try {
			compile()
				.setVerbose( arguments.verbose )
				.fromSource( "src/invalid/java" )
				.toClasses( "classes/invalid-source" )
				.run();
		} catch( any e ) {
			compileFailed = true;
		}

		assertEquals( true, compileFailed );
		assertEquals(
			beforeTempFiles.sort( "textnocase" ).toList( chr(10) ),
			directoryList( tempDirectory, false, "array", "temp*.txt" ).sort( "textnocase" ).toList( chr(10) )
		);
		job.reset();
		setExitCode( 0 );

		print.greenLine( "Failed compile cleanup test passed." );
	}

	/**
	 * @test
	 */
	function jarOptions( boolean verbose=false ) {
		var jarFile = resolvePath( "build/libs/jar-options.jar" );

		compile()
			.setVerbose( arguments.verbose )
			.jarOptions( { "compress" : false } )
			.toJar( "jar-options.jar" )
			.run();

		assertFileExists( jarFile );
		assertJarEntryCompression( jarFile, "example/App.class", 0 );

		print.greenLine( "JAR options test passed." );
	}

	/**
	 * @test
	 */
	function sourceEncoding( boolean verbose=false ) {
		var classesDirectory = resolvePath( "classes/source-encoding" );
		var jarFile = resolvePath( "build/libs/source-encoding.jar" );

		if( directoryExists( classesDirectory ) ) {
			directoryDelete( classesDirectory, true );
		}

		compile()
			.setVerbose( arguments.verbose )
			.fromSource( "src/encoding/java" )
			.compileOptions( { "encoding" : "UTF-8" } )
			.toClasses( "classes/source-encoding" )
			.toJar( "source-encoding.jar" )
			.run();

		assertFileExists( classesDirectory & "/example/encoding/EncodingApp.class" );
		assertFileExists( jarFile );

		classLoad( jarFile );
		var app = createObject( "java", "example.encoding.EncodingApp" ).init();
		assertEquals( "café", app.message() );

		print.greenLine( "Source encoding test passed." );
	}

	/**
	 * @test
	 */
	function optionsValidation( boolean verbose=false ) {
		var compilerFailed = false;
		var jarFailed = false;

		try {
			compile().compileOptions( { "unknown" : true } );
		} catch( any e ) {
			compilerFailed = true;
		}
		try {
			compile().jarOptions( { "unknown" : true } );
		} catch( any e ) {
			jarFailed = true;
		}

		assertEquals( true, compilerFailed );
		assertEquals( true, jarFailed );
		print.greenLine( "Options validation test passed." );
	}

	/**
	 * @test
	 */
	function boxJsonDefaults( boolean verbose=false ) {
		var projectRoot = resolvePath( "boxjson-fixture" );
		var classesDirectory = projectRoot & "/custom-classes";
		var jarFile = projectRoot & "/custom-libs/boxjson-app.jar";

		if( directoryExists( projectRoot & "/custom-classes" ) ) {
			directoryDelete( projectRoot & "/custom-classes", true );
		}
		if( directoryExists( projectRoot & "/custom-libs" ) ) {
			directoryDelete( projectRoot & "/custom-libs", true );
		}
		if( directoryExists( projectRoot & "/build" ) ) {
			directoryDelete( projectRoot & "/build", true );
		}

		// No DSL config at all — everything comes from box.json -> java
		compile( "boxjson-fixture" )
			.setVerbose( arguments.verbose )
			.run();

		assertFileExists( classesDirectory & "/example/boxjson/BoxJsonApp.class" );
		assertFileExists( jarFile );
		assertJarManifestValue( jarFile, "Bundle-Name", "BoxJSON Compile Test" );
		assertJarManifestValue( jarFile, "Bundle-Version", "2.0.0" );
		assertJarManifestValue( jarFile, "Implementation-Title", "BoxJSON Override" );
		assertFileExists( projectRoot & "/build/docs/javadoc/index.html" );

		print.greenLine( "Box.json defaults test passed." );
	}

	/**
	 * @test
	 */
	function boxJsonDslOverride( boolean verbose=false ) {
		var projectRoot = resolvePath( "boxjson-fixture" );
		var jarFile = projectRoot & "/custom-libs/dsl-override.jar";

		if( fileExists( jarFile ) ) {
			fileDelete( jarFile );
		}
		if( fileExists( projectRoot & "/custom-libs/boxjson-app.jar" ) ) {
			fileDelete( projectRoot & "/custom-libs/boxjson-app.jar" );
		}

		compile( "boxjson-fixture" )
			.setVerbose( arguments.verbose )
			.toJar( "dsl-override.jar" )
			.run();

		assertFileExists( jarFile );
		assertFileMissing( projectRoot & "/custom-libs/boxjson-app.jar" );

		print.greenLine( "Box.json DSL override test passed." );
	}

	/**
	 * @test
	 */
	function boxJsonDslDisable( boolean verbose=false ) {
		var projectRoot = resolvePath( "boxjson-fixture" );
		var classesDirectory = projectRoot & "/custom-classes";
		var jarFile = projectRoot & "/custom-libs/boxjson-app.jar";

		if( fileExists( jarFile ) ) {
			fileDelete( jarFile );
		}

		compile( "boxjson-fixture" )
			.setVerbose( arguments.verbose )
			.setCreateJar( false )
			.setUseJavaDoc( false )
			.run();

		assertFileExists( classesDirectory & "/example/boxjson/BoxJsonApp.class" );
		assertFileMissing( jarFile );

		print.greenLine( "Box.json DSL disable test passed." );
	}

	private function assertFileExists( required string filePath ) {
		if( !fileExists( arguments.filePath ) ) {
			error( "Expected file was not created: #arguments.filePath#" );
		}
	}

	private function assertFileMissing( required string filePath ) {
		if( fileExists( arguments.filePath ) ) {
			error( "Expected file to be missing: #arguments.filePath#" );
		}
	}

	private function assertEquals( required expected, required actual ) {
		if( arguments.expected != arguments.actual ) {
			error( "Expected [#arguments.expected#], received [#arguments.actual#]." );
		}
	}

	private function assertStructKeys( required struct value, required array keys ) {
		for( var key in arguments.keys ) {
			if( !arguments.value.keyExists( key ) ) {
				error( "Expected result key was not returned: #key#" );
			}
		}
	}

	private function assertJarEntryExists( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );

		try {
			if( isNull( jar.getJarEntry( arguments.entryName ) ) ) {
				error( "Expected JAR entry was not found: #arguments.entryName#" );
			}
		} finally {
			jar.close();
		}
	}

	private function assertJarEntryMissing( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );

		try {
			if( !isNull( jar.getJarEntry( arguments.entryName ) ) ) {
				error( "Unexpected JAR entry was found: #arguments.entryName#" );
			}
		} finally {
			jar.close();
		}
	}

	private function readJarEntry( required string jarFile, required string entryName ) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );

		try {
			var entry = jar.getJarEntry( arguments.entryName );
			if( isNull( entry ) ) {
				error( "Expected JAR entry was not found: #arguments.entryName#" );
			}
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

	private function createServiceDependencyJar(
		required string directory,
		required string jarFile,
		required string provider,
		string signatureFile=""
	) {
		if( directoryExists( arguments.directory ) ) {
			directoryDelete( arguments.directory, true );
		}
		if( fileExists( arguments.jarFile ) ) {
			fileDelete( arguments.jarFile );
		}

		directoryCreate( arguments.directory & "/META-INF/services", true );
		fileWrite( arguments.directory & "/META-INF/services/example.Service", arguments.provider & chr(10) );
		if( arguments.signatureFile.len() ) {
			fileWrite( arguments.directory & "/META-INF/" & arguments.signatureFile, "invalid signature" );
		}

		var zipFile = arguments.jarFile & ".zip";
		if( fileExists( zipFile ) ) {
			fileDelete( zipFile );
		}
		zip action="zip" file="#arguments.jarFile#" source="#arguments.directory#" overwrite="true";
		fileMove( zipFile, arguments.jarFile );
	}

	private function createResourceDependencyJar(
		required string directory,
		required string jarFile,
		required string resourceContents
	) {
		if( directoryExists( arguments.directory ) ) {
			directoryDelete( arguments.directory, true );
		}
		if( fileExists( arguments.jarFile ) ) {
			fileDelete( arguments.jarFile );
		}

		directoryCreate( arguments.directory, true );
		fileWrite( arguments.directory & "/duplicate-resource.txt", arguments.resourceContents & chr(10) );

		var zipFile = arguments.jarFile & ".zip";
		if( fileExists( zipFile ) ) {
			fileDelete( zipFile );
		}
		zip action="zip" file="#arguments.jarFile#" source="#arguments.directory#" overwrite="true";
		fileMove( zipFile, arguments.jarFile );
	}

	private function assertJarManifestValue(
		required string jarFile,
		required string attributeName,
		required string expectedValue
	) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );

		try {
			var actualValue = jar.getManifest().getMainAttributes().getValue( arguments.attributeName );
			assertEquals( arguments.expectedValue, actualValue );
		} finally {
			jar.close();
		}
	}

	private function assertClassMajorVersion( required string classFile, required numeric expectedVersion ) {
		var input = createObject( "java", "java.io.DataInputStream" ).init(
			createObject( "java", "java.io.FileInputStream" ).init( arguments.classFile )
		);

		try {
			input.readInt();
			input.readUnsignedShort();
			assertEquals( arguments.expectedVersion, input.readUnsignedShort() );
		} finally {
			input.close();
		}
	}

	private function assertJarEntryCompression(
		required string jarFile,
		required string entryName,
		required numeric expectedMethod
	) {
		var jar = createObject( "java", "java.util.jar.JarFile" ).init( arguments.jarFile );

		try {
			var entry = jar.getJarEntry( arguments.entryName );
			if( isNull( entry ) ) {
				error( "Expected JAR entry was not found: #arguments.entryName#" );
			}
			assertEquals( arguments.expectedMethod, entry.getMethod() );
		} finally {
			jar.close();
		}
	}

}
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
	 * Merging a large number of dependencies must keep the documented merge
	 * semantics, put resources in the fat JAR even when the thin JAR has another
	 * name, and stay linear instead of rewriting the output once per dependency.
	 *
	 * @test
	 */
	function fatJarManyDependencies( boolean verbose=false ) {
		var dependencyCount = 40;
		var fixtureRoot = resolvePath( "fat-jar-many" );
		var thinJarFile = resolvePath( "build/libs/fat-jar-many-thin.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-many-all.jar" );
		var firstPolicyJarFile = resolvePath( "build/libs/fat-jar-many-first.jar" );
		var inPlaceJarFile = resolvePath( "build/libs/fat-jar-many-inplace.jar" );
		var guardedJarFile = resolvePath( "build/libs/fat-jar-many-guarded.jar" );
		var dependencyJars = [];
		var expectedProviders = [];

		if( directoryExists( fixtureRoot ) ) {
			directoryDelete( fixtureRoot, true );
		}
		for( var jarPath in [ thinJarFile, jarFile, firstPolicyJarFile, inPlaceJarFile, guardedJarFile ] ) {
			if( fileExists( jarPath ) ) {
				fileDelete( jarPath );
			}
		}

		for( var i = 1; i <= dependencyCount; i++ ) {
			var dependencyJar = resolvePath( "libs/fat-jar-many-#i#.jar" );
			createManyDependencyJar( fixtureRoot & "/dependency-#i#", dependencyJar, i );
			dependencyJars.append( dependencyJar );
			if( i % 5 == 0 ) {
				expectedProviders.append( "example.provider.Provider#i#" );
			}
		}

		var startedAt = getTickCount();
		var result = compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-many-thin.jar" )
			.toFatJar( "fat-jar-many-all.jar", dependencyJars )
			.run();
		var elapsedSeconds = ( getTickCount() - startedAt ) / 1000;

		assertFileExists( result.jarPath );
		assertEquals( "fat-jar-many-all.jar", getFileFromPath( result.jarPath ) );
		assertFileExists( thinJarFile );
		assertFileExists( jarFile );
		assertJarEntryMissing( thinJarFile, "many/unique-1.txt" );
		assertJarEntryExists( jarFile, "many/unique-1.txt" );
		assertJarEntryExists( jarFile, "many/unique-#dependencyCount#.txt" );
		// Signature files from dependencies are excluded by default
		assertJarEntryMissing( jarFile, "META-INF/SIGNATURE.SF" );

		// Service descriptors are merged line by line, in the supplied dependency order
		assertEquals(
			expectedProviders.toList( chr(10) ),
			readJarEntry( jarFile, "META-INF/services/example.ManyService" )
		);
		// The default duplicate policy keeps the last dependency supplied
		assertEquals( "dependency #dependencyCount#", readJarEntry( jarFile, "many/duplicate.txt" ) );
		// Resources belong in the fat JAR when the thin JAR has another name
		assertJarEntryExists( jarFile, "default-resource.txt" );
		assertJarEntryExists( jarFile, "nested/default-nested-resource.txt" );

		compile()
			.setVerbose( arguments.verbose )
			.configureFatJar( { "duplicatePolicy" : "first" } )
			.toJar( "fat-jar-many-thin-first.jar" )
			.toFatJar( "fat-jar-many-first.jar", dependencyJars )
			.run();

		assertEquals( "dependency 1", readJarEntry( firstPolicyJarFile, "many/duplicate.txt" ) );

		// A JAR left behind by a previous run must be replaced, not merged into
		compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-many-thin.jar" )
			.toFatJar( "fat-jar-many-all.jar", [ dependencyJars.first() ] )
			.run();

		assertJarEntryExists( jarFile, "many/unique-1.txt" );
		assertJarEntryMissing( jarFile, "many/unique-#dependencyCount#.txt" );

		// The fat JAR may be written in place over the thin JAR name
		compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-many-inplace.jar" )
			.toFatJar( "fat-jar-many-inplace.jar", dependencyJars )
			.run();

		assertJarEntryExists( inPlaceJarFile, "many/unique-1.txt" );
		assertJarEntryExists( inPlaceJarFile, "default-resource.txt" );
		assertEquals(
			expectedProviders.toList( chr(10) ),
			readJarEntry( inPlaceJarFile, "META-INF/services/example.ManyService" )
		);

		// A failed merge must leave the previous JAR untouched and drop no temp file next to it
		compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-many-guarded-thin.jar" )
			.toFatJar( "fat-jar-many-guarded.jar", [ dependencyJars.first() ] )
			.run();
		var duplicateBeforeFailure = readJarEntry( guardedJarFile, "many/duplicate.txt" );
		var mergeFailed = false;
		try {
			compile()
				.setVerbose( arguments.verbose )
				.toJar( "fat-jar-many-guarded-thin.jar" )
				.toFatJar( "fat-jar-many-guarded.jar", dependencyJars, { "duplicatePolicy" : "error" } )
				.run();
		} catch( any e ) {
			mergeFailed = true;
		}
		assertEquals( true, mergeFailed );
		job.reset();
		setExitCode( 0 );

		assertFileExists( guardedJarFile );
		assertFileMissing( guardedJarFile & ".tmp" );
		assertEquals( duplicateBeforeFailure, readJarEntry( guardedJarFile, "many/duplicate.txt" ) );
		assertJarEntryMissing( guardedJarFile, "many/unique-#dependencyCount#.txt" );

		// A linear merge of the whole dependency set must not blow up into a multi-minute build
		if( elapsedSeconds > 60 ) {
			error( "Merging #dependencyCount# dependency JARs took #elapsedSeconds# seconds." );
		}

		print.greenLine( "Fat-JAR many dependency test passed in #elapsedSeconds# seconds." );
	}

	/**
	 * A dependency JarIndex must never reach the merged archive, and duplicate
	 * entries must be reported with the source JARs that produced them.
	 *
	 * @test
	 */
	function fatJarIndexListAndDuplicates( boolean verbose=false ) {
		var firstDirectory = resolvePath( "fat-jar-index/first" );
		var secondDirectory = resolvePath( "fat-jar-index/second" );
		var firstJar = resolvePath( "libs/fat-jar-index-first.jar" );
		var secondJar = resolvePath( "libs/fat-jar-index-second.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-index.jar" );

		createIndexedDependencyJar( firstDirectory, firstJar, "first dependency" );
		createIndexedDependencyJar( secondDirectory, secondJar, "second dependency" );

		var dsl = compile()
			.setVerbose( arguments.verbose )
			.toJar( "fat-jar-index-src.jar" )
			.toFatJar( "fat-jar-index.jar", [ firstJar, secondJar ] );
		dsl.run();

		// A JarIndex only describes the archive it was written for
		assertJarEntryMissing( jarFile, "META-INF/INDEX.LIST" );
		// The last dependency applied wins the shared entry
		assertEquals( "second dependency", readJarEntry( jarFile, "indexed-resource.txt" ) );

		// The resolved duplicate is reported with both source JARs
		var duplicates = dsl.getFatJarDuplicateReport();
		assertEquals( 2, duplicates.len() );
		var classDuplicates = duplicates.filter(
			( duplicate ) => duplicate.entry == "example/shared/Duplicate.class"
		);
		assertEquals( 1, classDuplicates.len() );
		assertEquals( "last", classDuplicates.first().policy );
		assertEquals( true, classDuplicates.first().keptJar.endsWith( "fat-jar-index-second.jar" ) );
		assertEquals( true, classDuplicates.first().skippedJar.endsWith( "fat-jar-index-first.jar" ) );

		print.greenLine( "Fat-JAR index list and duplicate report test passed." );
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

	/**
	 * Project resources participate in service descriptor merging, so a descriptor
	 * that exists in both the project resources and a dependency keeps every
	 * provider instead of one side overwriting the other.
	 *
	 * @test
	 */
	function fatJarProjectResourceServices( boolean verbose=false ) {
		var projectResources = resolvePath( "fat-jar-resources" );
		var dependencyDirectory = resolvePath( "fat-jar-resources-dep" );
		var dependencyJar = resolvePath( "libs/fat-jar-resources-dep.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-resources.jar" );

		if( directoryExists( projectResources ) ) {
			directoryDelete( projectResources, true );
		}
		directoryCreate( projectResources & "/META-INF/services", true );
		fileWrite(
			projectResources & "/META-INF/services/example.UnionService",
			"project.one" & chr( 10 ) & "project.two" & chr( 10 )
		);
		fileWrite( projectResources & "/resource-wins.txt", "project" & chr( 10 ) );

		createResourceServiceDependencyJar( dependencyDirectory, dependencyJar );

		compile()
			.setVerbose( arguments.verbose )
			.withResources( "fat-jar-resources" )
			.toJar( "fat-jar-resources-src.jar" )
			.toFatJar( "fat-jar-resources.jar", [ dependencyJar ] )
			.run();

		assertFileExists( jarFile );
		// Dependency providers first, then the project providers, nothing dropped
		assertEquals(
			"dep.one#chr( 10 )#dep.two#chr( 10 )#dep.three#chr( 10 )#project.one#chr( 10 )#project.two",
			readJarEntry( jarFile, "META-INF/services/example.UnionService" )
		);
		// Non-service resources still win over the dependency copy
		assertEquals( "project", readJarEntry( jarFile, "resource-wins.txt" ) );
		assertEquals( "dependency only", readJarEntry( jarFile, "dep-only.txt" ) );

		print.greenLine( "Fat-JAR project resource service merge test passed." );
	}

	/**
	 * A fat JAR build without a toJar() call produces only the fat JAR.
	 *
	 * @test
	 */
	function fatJarWithoutThinJar( boolean verbose=false ) {
		var dependencyJar = resolvePath( "libs/fat-jar-lone-dep.jar" );
		var jarFile = resolvePath( "build/libs/lone-fat.jar" );

		createManyDependencyJar( resolvePath( "fat-jar-lone" ), dependencyJar, 1 );

		var dsl = compile()
			.setVerbose( arguments.verbose )
			.toFatJar( "lone-fat.jar", [ dependencyJar ] );
		dsl.run();

		assertFileExists( jarFile );
		assertJarEntryExists( jarFile, "many/unique-1.txt" );
		// The thin JAR was only the merge input, so it must not be left behind
		assertFileMissing( resolvePath( "build/libs/" & listLast( dsl.getJarNameString(), "/\" ) ) );

		print.greenLine( "Fat-JAR without thin JAR test passed." );
	}

	/**
	 * fatJarJars accepts a directory the same way classPath does, including a mix
	 * of directories and explicit JAR paths.
	 *
	 * @test
	 */
	function fatJarJarsDirectory( boolean verbose=false ) {
		var dependencyDirectory = resolvePath( "libs/fat-jar-dir-deps" );
		var emptyDirectory = resolvePath( "libs/fat-jar-dir-empty" );
		var standaloneJar = resolvePath( "libs/fat-jar-dir-standalone.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-dir.jar" );
		var mixedJarFile = resolvePath( "build/libs/fat-jar-dir-mixed.jar" );

		if( directoryExists( dependencyDirectory ) ) {
			directoryDelete( dependencyDirectory, true );
		}
		directoryCreate( dependencyDirectory, true );
		for( var i = 1; i <= 3; i++ ) {
			createManyDependencyJar(
				resolvePath( "fat-jar-dir/source-#i#" ),
				dependencyDirectory & "/dependency-#i#.jar",
				i
			);
		}
		createManyDependencyJar( resolvePath( "fat-jar-dir/source-standalone" ), standaloneJar, 99 );

		// A directory expands to every JAR it contains
		compile()
			.setVerbose( arguments.verbose )
			.toFatJar( "fat-jar-dir.jar", dependencyDirectory )
			.run();

		assertJarEntryExists( jarFile, "many/unique-1.txt" );
		assertJarEntryExists( jarFile, "many/unique-2.txt" );
		assertJarEntryExists( jarFile, "many/unique-3.txt" );
		assertJarEntryMissing( jarFile, "many/unique-99.txt" );

		// Directories and explicit JAR paths can be mixed
		compile()
			.setVerbose( arguments.verbose )
			.toFatJar( "fat-jar-dir-mixed.jar", [ dependencyDirectory, standaloneJar ] )
			.run();

		assertJarEntryExists( mixedJarFile, "many/unique-1.txt" );
		assertJarEntryExists( mixedJarFile, "many/unique-99.txt" );

		// An empty directory reports the directory, not a bogus JAR path
		if( directoryExists( emptyDirectory ) ) {
			directoryDelete( emptyDirectory, true );
		}
		directoryCreate( emptyDirectory, true );
		var emptyDirectoryError = "";
		try {
			compile().toFatJar( "fat-jar-dir-empty.jar", emptyDirectory );
		} catch( any e ) {
			emptyDirectoryError = e.message;
		}
		assertEquals( true, emptyDirectoryError.contains( "contains no JAR files" ) );
		assertEquals( true, emptyDirectoryError.contains( "fat-jar-dir-empty" ) );

		job.reset();
		setExitCode( 0 );

		print.greenLine( "Fat-JAR directory dependencies test passed." );
	}

	/**
	 * A fat JAR requested without a dependency list merges the compile class path,
	 * and an empty merge is reported instead of silently producing a thin JAR.
	 *
	 * @test
	 */
	function fatJarDefaultsToClassPath( boolean verbose=false ) {
		var dependencyDirectory = resolvePath( "libs/fat-jar-default-deps" );
		var otherJar = resolvePath( "libs/fat-jar-default-other.jar" );
		var jarFile = resolvePath( "build/libs/fat-jar-default.jar" );
		var explicitJarFile = resolvePath( "build/libs/fat-jar-default-explicit.jar" );
		var noDepsJarFile = resolvePath( "build/libs/fat-jar-default-none.jar" );

		if( directoryExists( dependencyDirectory ) ) {
			directoryDelete( dependencyDirectory, true );
		}
		directoryCreate( dependencyDirectory, true );
		for( var i = 1; i <= 2; i++ ) {
			createManyDependencyJar(
				resolvePath( "fat-jar-default/source-#i#" ),
				dependencyDirectory & "/dependency-#i#.jar",
				i
			);
		}
		createManyDependencyJar( resolvePath( "fat-jar-default/source-other" ), otherJar, 99 );

		// No fatJarJars supplied: the compile class path is the dependency set
		var result = compile()
			.setVerbose( arguments.verbose )
			.withClassPath( dependencyDirectory )
			.toFatJar( "fat-jar-default.jar" )
			.run();

		assertJarEntryExists( jarFile, "many/unique-1.txt" );
		assertJarEntryExists( jarFile, "many/unique-2.txt" );
		assertJarEntryMissing( jarFile, "many/unique-99.txt" );
		assertEquals( 2, result.fatJarDependencyCount );
		assertEquals( 2, result.fatJarPaths.len() );

		// An explicit dependency list still wins over the class path
		compile()
			.setVerbose( arguments.verbose )
			.withClassPath( dependencyDirectory )
			.toFatJar( "fat-jar-default-explicit.jar", [ otherJar ] )
			.run();

		assertJarEntryExists( explicitJarFile, "many/unique-99.txt" );
		assertJarEntryMissing( explicitJarFile, "many/unique-1.txt" );

		// Nothing to merge is reported rather than silently skipped
		var emptyResult = compile()
			.setVerbose( arguments.verbose )
			.toFatJar( "fat-jar-default-none.jar" )
			.run();

		assertFileExists( noDepsJarFile );
		assertJarEntryExists( noDepsJarFile, "example/App.class" );
		assertEquals( 0, emptyResult.fatJarDependencyCount );
		assertEquals( true, emptyResult.fatJarRequested );

		print.greenLine( "Fat-JAR class path default test passed." );
	}

	/**
	 * java.resources accepts multiple roots: repeated withResources() calls and
	 * comma-delimited or array values accumulate, and a later root wins shared
	 * entries. Both the thin and the fat JAR must contain every root.
	 *
	 * @test
	 */
	function multipleResourceRoots( boolean verbose=false ) {
		var firstRoot = resolvePath( "resources-fixture/checked-in" );
		var secondRoot = resolvePath( "resources-fixture/generated" );
		var thinJar = resolvePath( "build/libs/multi-resources.jar" );
		var fatJar = resolvePath( "build/libs/multi-resources-fat.jar" );

		if( directoryExists( resolvePath( "resources-fixture" ) ) ) {
			directoryDelete( resolvePath( "resources-fixture" ), true );
		}
		directoryCreate( firstRoot & "/shared", true );
		directoryCreate( secondRoot & "/shared", true );
		fileWrite( firstRoot & "/only-a.txt", "a" & chr( 10 ) );
		fileWrite( firstRoot & "/shared/overlap.txt", "first" & chr( 10 ) );
		fileWrite( secondRoot & "/only-b.txt", "b" & chr( 10 ) );
		fileWrite( secondRoot & "/shared/overlap.txt", "second" & chr( 10 ) );

		// Repeated calls accumulate, the later root wins shared entries
		var thinResult = compile()
			.setVerbose( arguments.verbose )
			.withResources( "resources-fixture/checked-in" )
			.withResources( "resources-fixture/generated" )
			.toJar( "multi-resources.jar" )
			.run();

		assertEquals( 2, thinResult.resourcePaths.len() );
		assertJarEntryExists( thinJar, "only-a.txt" );
		assertJarEntryExists( thinJar, "only-b.txt" );
		assertEquals( "second", readJarEntry( thinJar, "shared/overlap.txt" ) );
		// The first explicit configuration replaces the src/main/resources default
		assertJarEntryMissing( thinJar, "default-resource.txt" );

		// An array of roots merges the same way into a fat JAR
		var fatResult = compile()
			.setVerbose( arguments.verbose )
			.withResources( [ firstRoot, secondRoot ] )
			.toJar( "multi-resources-thin.jar" )
			.toFatJar( "multi-resources-fat.jar" )
			.run();

		assertEquals( 2, fatResult.resourcePaths.len() );
		assertJarEntryExists( fatJar, "only-a.txt" );
		assertJarEntryExists( fatJar, "only-b.txt" );
		assertEquals( "second", readJarEntry( fatJar, "shared/overlap.txt" ) );
		assertJarEntryMissing( fatJar, "default-resource.txt" );

		print.greenLine( "Multiple resource roots test passed." );
	}

	/**
	 * preJavaCompile and postJavaCompile bookend the whole DSL run and fire the
	 * package scripts of the same name. preJavaCompile runs before anything is
	 * built, so it can generate sources/resources; postJavaCompile runs last.
	 *
	 * @test
	 */
	function compileInterceptionScripts( boolean verbose=false ) {
		var projectRoot = resolvePath( "compile-scripts-fixture" );
		var jarFile = projectRoot & "/build/libs/compile-scripts.jar";
		var preMarker = projectRoot & "/pre-java-compile.marker";
		var postMarker = projectRoot & "/post-java-compile.marker";

		for( var path in [ projectRoot & "/build", projectRoot & "/dist", preMarker, postMarker ] ) {
			if( directoryExists( path ) ) {
				directoryDelete( path, true );
			} else if( fileExists( path ) ) {
				fileDelete( path );
			}
		}

		var result = compile( "compile-scripts-fixture" )
			.setVerbose( arguments.verbose )
			.run();

		assertFileExists( preMarker );
		assertFileExists( postMarker );
		assertFileExists( jarFile );
		// Written by the preJavaCompile script, so it proves the script ran before the JAR was built
		assertJarEntryExists( jarFile, "pre-resource.txt" );
		assertJarEntryExists( jarFile, "example/ScriptsApp.class" );
		assertEquals( true, result.jarPath.replaceNoCase( "\", "/" ).endsWith( "compile-scripts.jar" ) );

		print.greenLine( "Compile interception scripts test passed." );
	}

	function classPathRegressions( boolean verbose = false ) {
		distClassPaths( arguments.verbose );
		globberPatternConsistency();
		classEntryValidation();
	}

	/** @test */
	function distClassPaths( boolean verbose = false ) {
		var project = resolvePath( "build/dist-path-fixture" );
		directoryCreate( project & "/src/main/java", true, true );
		fileWrite( project & "/src/main/java/Placeholder.java", "public class Placeholder {}" );
		fileWrite( project & "/box.json", serializeJSON( {
			"slug" : "dist-paths",
			"version" : "1.0.0",
			"java" : {
				"classes" : "dist/classes/",
				"libsDir" : "dist/libs",
				"jar" : true,
				"fatJar" : true
			}
		} ) );
		var result = compile( project ).setVerbose( arguments.verbose ).run();
		assertJarEntryExists( result.jarPath, "Placeholder.class" );
		assertJarEntryMissing( result.jarPath, "dist/classes/Placeholder.class" );

		var explicit = compile( project )
			.toClasses( "dist/release/classes with spaces/" )
			.libsDir( "dist/release/libs" )
			.run();
		assertJarEntryExists( explicit.jarPath, "Placeholder.class" );
		print.greenLine( "Dist and release-layout JAR paths passed." ).toConsole();
	}

	/** @test */
	function globberPatternConsistency( boolean verbose = false ) {
		var classes = resolvePath( "build/globber-fixture" );
		directoryCreate( classes & "/nested", true, true );
		fileWrite( classes & "/Root.class", "" );
		fileWrite( classes & "/nested/Child.class", "" );
		for( var suffix in [ "/**.class", "/**/*.class", "/*.class" ] ) {
			var cleanClasses = reReplace( classes, "[\\/]+$", "" );
			for( var directory in [ replace( cleanClasses, "\", "/", "all" ), cleanClasses ] ) {
				var pattern = directory & suffix;
				var globber = wirebox.getInstance( "globber" );
				var stringMatches = globber.setPattern( pattern ).asQuery().matches();
				var arrayMatches = wirebox.getInstance( "globber" )
					.setPattern( [ pattern ] ).asQuery().matches();
				assertEquals( suffix == "/*.class" ? 1 : 2, stringMatches.recordCount );
				assertEquals( serializeJSON( stringMatches ), serializeJSON( arrayMatches ) );
				for( var row in stringMatches ) {
					assertStructKeys( row, [ "directory", "name", "type" ] );
					assertEquals( true, compareNoCase( row.type, "file" ) == 0 );
					assertEquals( true, fileExists( row.directory & "/" & row.name ) );
				}
			}
		}
		print.greenLine( "String, array, and row shape checks passed." ).toConsole();
	}

	/** @test */
	function classEntryValidation( boolean verbose = false ) {
		var classes = reReplace( resolvePath( "build/class-entry-validation" ), "[\\/]+$", "" );
		directoryCreate( classes & "/empty", true, true );
		directoryCreate( classes & "/empty/NotAFile.class", true, true );
		directoryCreate( classes & "/populated", true, true );
		fileWrite( classes & "/populated/Present.class", "" );
		var responseFile = classes & "/entries.txt";
		try {
			for( var folder in [ "empty", "populated", "missing" ] ) {
				var output = classes & "/" & folder;
				var dsl = compile().toClasses( output );
				var caught = false;
				try {
					var pattern = output & ( folder == "populated" ? "/**/Absent.class" : "/**.class" );
					dsl.writeTempClassFiles( responseFile, [ pattern ] );
				} catch( commandException e ) {
					caught = true;
					assertEquals( true, e.message.contains( "No .class files found" ) );
					assertEquals( true, e.message.contains( folder ) );
					assertEquals( true, e.message.contains( fileSystemUtil.normalizeSlashes( output ) ) );
				}
				assertEquals( true, caught );
				assertFileMissing( responseFile );
			}
			var caught = false;
			try {
				compile().toClasses( classes & "/empty" )
					.writeTempClassFiles( responseFile, [ classes & "/populated/**.class" ] );
			} catch( commandException e ) {
				caught = true;
				assertEquals( true, e.message.contains( "Present.class" ) );
				assertEquals( true, e.message.contains( "relative to classes directory" ) );
			}
			assertEquals( true, caught );
			assertFileMissing( responseFile );
		} finally {
			if( fileExists( responseFile ) ) fileDelete( responseFile );
		}
		print.greenLine( "Empty, unmatched, missing, and out-of-root class checks passed." ).toConsole();
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

	/**
	 * Builds one dependency JAR for the many-dependency merge test. Every fifth
	 * JAR also ships a service provider descriptor and the first JAR carries a
	 * signature file.
	 */
	private function createManyDependencyJar(
		required string directory,
		required string jarFile,
		required numeric index
	) {
		if( directoryExists( arguments.directory ) ) {
			directoryDelete( arguments.directory, true );
		}
		if( fileExists( arguments.jarFile ) ) {
			fileDelete( arguments.jarFile );
		}

		directoryCreate( arguments.directory & "/many", true );
		fileWrite( arguments.directory & "/many/unique-#arguments.index#.txt", "dependency #arguments.index#" & chr(10) );
		fileWrite( arguments.directory & "/many/duplicate.txt", "dependency #arguments.index#" & chr(10) );

		if( arguments.index == 1 ) {
			directoryCreate( arguments.directory & "/META-INF", true );
			fileWrite( arguments.directory & "/META-INF/SIGNATURE.SF", "invalid signature" );
		}
		if( arguments.index % 5 == 0 ) {
			directoryCreate( arguments.directory & "/META-INF/services", true );
			fileWrite(
				arguments.directory & "/META-INF/services/example.ManyService",
				"example.provider.Provider#arguments.index#" & chr(10)
			);
		}

		var zipFile = arguments.jarFile & ".zip";
		if( fileExists( zipFile ) ) {
			fileDelete( zipFile );
		}
		zip action="zip" file="#arguments.jarFile#" source="#arguments.directory#" overwrite="true";
		fileMove( zipFile, arguments.jarFile );
	}

	/**
	 * Builds a dependency JAR that ships a JarIndex, a shared class, and a unique
	 * resource, used by the index list and duplicate reporting test.
	 */
	private function createIndexedDependencyJar(
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

		directoryCreate( arguments.directory & "/META-INF", true );
		directoryCreate( arguments.directory & "/example/shared", true );
		fileWrite(
			arguments.directory & "/META-INF/INDEX.LIST",
			"JarIndex-Version: 1.0" & chr( 10 ) & chr( 10 ) & arguments.jarFile & chr( 10 )
		);
		fileWrite( arguments.directory & "/example/shared/Duplicate.class", "shared class placeholder" );
		fileWrite( arguments.directory & "/indexed-resource.txt", arguments.resourceContents & chr( 10 ) );

		var zipFile = arguments.jarFile & ".zip";
		if( fileExists( zipFile ) ) {
			fileDelete( zipFile );
		}
		zip action="zip" file="#arguments.jarFile#" source="#arguments.directory#" overwrite="true";
		fileMove( zipFile, arguments.jarFile );
	}

	/**
	 * Builds a dependency JAR for the project resource merge test: a service
	 * descriptor with three providers plus resources that collide with the project.
	 */
	private function createResourceServiceDependencyJar(
		required string directory,
		required string jarFile
	) {
		if( directoryExists( arguments.directory ) ) {
			directoryDelete( arguments.directory, true );
		}
		if( fileExists( arguments.jarFile ) ) {
			fileDelete( arguments.jarFile );
		}

		directoryCreate( arguments.directory & "/META-INF/services", true );
		fileWrite(
			arguments.directory & "/META-INF/services/example.UnionService",
			"dep.one" & chr( 10 ) & "dep.two" & chr( 10 ) & "dep.three" & chr( 10 )
		);
		fileWrite( arguments.directory & "/resource-wins.txt", "dependency" & chr( 10 ) );
		fileWrite( arguments.directory & "/dep-only.txt", "dependency only" & chr( 10 ) );

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
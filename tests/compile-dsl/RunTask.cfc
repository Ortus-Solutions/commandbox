/**
 * Tests for the `java run` command.
 *
 * Each test compiles a fixture with `java compile` first (java run does not
 * compile), then exercises a java run use case.
 */
component {

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
	 * @test
	 */
	function runHelloWorld() {
		cleanFixture();
		runJavaRun(); // should not throw - output streams to console
		print.greenLine( "Run hello world test passed." );
	}

	/**
	 * @test
	 */
	function runWithMainClassOverride() {
		cleanFixture();
		runJavaRun( { "mainClass" = "example.Example" } );
		print.greenLine( "Run main-class override test passed." );
	}

	/**
	 * @test
	 */
	function runWithProgramArgs() {
		cleanFixture();
		runJavaRun( { "args" = "hello world" } );
		print.greenLine( "Run program args test passed." );
	}

	/**
	 * The args param accepts a struct of numeric keys (what the raw shell's
	 * `:N=value` dynamic params produce). Passing the struct directly through
	 * the DSL exercises the same code path.
	 *
	 * @test
	 */
	function runWithDynamicArgs() {
		cleanFixture();
		runJavaRun( { "args" : { "1" = "one", "2" = "two" } } );
		print.greenLine( "Run dynamic args test passed." );
	}

	/**
	 * JVM args (leading single hyphen) are split out of args and routed to
	 * the java executable, while the rest go to main().
	 *
	 * @test
	 */
	function runWithJvmArgs() {
		cleanFixture();
		runJavaRun( { "args" = "-Xmx512m -Dtest.prop=works arg1 arg2" } );
		print.greenLine( "Run JVM args test passed." );
	}

	/**
	 * box.json java.runArgs provides default args that are merged in before
	 * the user-provided args.
	 *
	 * @test
	 */
	function runWithConfigArgs() {
		cleanFixture();
		// run-fixture box.json has runArgs: [ "from-config" ]
		runJavaRun();
		print.greenLine( "Run config args test passed." );
	}

	/**
	 * A string runArgs is split on spaces and each arg is routed correctly -
	 * JVM flags to the JVM, everything else to main(). Four args alternating
	 * between JVM and program args.
	 *
	 * @test
	 */
	function runWithStringConfigArgs() {
		cleanFixture();
		// Temporarily set a string runArgs that alternates JVM/user args
		var boxJsonPath = resolvePath( "run-fixture/box.json" );
		var boxJSON = deserializeJSON( fileRead( boxJsonPath ) );
		boxJSON.java.runArgs = "one -Dtest.prop=works two -Xmx256m";
		fileWrite( boxJsonPath, serializeJSON( boxJSON, true ) );
		try {
			runJavaRun();
		} finally {
			// Restore the array form
			boxJSON.java.runArgs = [ "from-config" ];
			fileWrite( boxJsonPath, serializeJSON( boxJSON, true ) );
		}
		print.greenLine( "Run string config args test passed." );
	}

	/**
	 * @test
	 */
	function runWithJavaVersion() {
		cleanFixture();
		runJavaRun( { "javaVersion" = "21" } );
		print.greenLine( "Run java version test passed." );
	}

	/**
	 * Errors when the JAR is missing and jar=true.
	 *
	 * @test
	 */
	function runMissingJar() {
		cleanFixture();
		// Compile, then delete the jar
		command( "java compile" )
			.inWorkingDirectory( resolvePath( "run-fixture" ) )
			.flags( "JSON" )
			.run();
		var jarPath = resolvePath( "run-fixture/build/libs/java-run-test.jar" );
		if( fileExists( jarPath ) ) {
			fileDelete( jarPath );
		}

		var failed = false;
		var message = "";
		try {
			command( "java run" ).inWorkingDirectory( resolvePath( "run-fixture" ) ).run();
		} catch( any e ) {
			failed = true;
			message = e.message;
		}
		assertTrue( failed, "Expected an error" );
		assertTrue( message.contains( "java compile" ), "Expected hint to compile, got: #message#" );
		print.greenLine( "Run missing jar test passed." );
	}

	private string function runJavaRun( struct params={} ) {
		// Compile first - java run does not compile
		command( "java compile" )
			.inWorkingDirectory( resolvePath( "run-fixture" ) )
			.flags( "JSON" )
			.run();

		return command( "java run" )
			.inWorkingDirectory( resolvePath( "run-fixture" ) )
			.params( argumentCollection = arguments.params )
			.run( returnOutput=true );
	}

	private void function cleanFixture() {
		var path = resolvePath( "run-fixture/build" );
		if( directoryExists( path ) ) directoryDelete( path, true );
	}

	private void function assertTrue( required boolean condition, required string message ) {
		if( !arguments.condition ) error( arguments.message );
	}

}

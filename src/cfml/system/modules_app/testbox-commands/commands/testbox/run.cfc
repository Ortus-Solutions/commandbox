/**
 * Executes TestBox runners via HTTP/S.  By default, the "testbox.runner" property will be read from your box.json.
 * If the property is a string, it will be used directly as a URL.
 * .
 * {code:bash}
 * testbox run
 * {code}
 *
 * If testbox.runner is an array of structs like so:
 * .
 * {code:bash}
 * |  "testbox" : {
 * |    "runner" : [
 * |      {
 * |        "server1" : "http://localhost/tests/runner.cfm",
 * |        "server2" : "/tests/runner.cfm"
 * |      }
 * |    ]
 * |  }
 * {code}
 * .
 * You target a specific URL by name.
 * .
 * {code:bash}
 * testbox run server1
 * testbox run server2
 * {code}
 * .
 * You can also specify the URL manually
 * {code:bash}
 * testbox run http://localhost:8080/tests/runner.cfm
 * {code}
 * .
 * If you have a CommandBox server running in the current directory, you can specify a partial URL that starts with /
 * {code:bash}
 * testbox run /tests/runner.cfm
 * {code}
 * .
 * You can set arbitrary URL options in our box.json like so
 * {code:bash}
 * package set testbox.options.opt1=value1
 * package set testbox.options.opt2=value2
 * {code}
 * .
 * You can set arbitrary URL options when you run the command like so
 * {code:bash}
 * testbox run options:opt1=value1 options:opt2=value2
 * {code}
 * .
 * You can run your tests and post-produce many reporting results, great for CI purposes
 * {code:bash}
 * testbox run outputformats=json,antjunit,simple
 * testbox run outputformats=json,antjunit,simple outputFile=myresults
 * {code}
 *
 **/
component {

	// DI
	property name="packageService" 	inject="PackageService";
	property name="testingService" 	inject="TestingService@testbox-commands";
	property name="CLIRenderer"    	inject="CLIRenderer@testbox-commands";
	property name="serverService"  	inject="ServerService";
	property name="moduleConfig"  	inject="box:moduleConfig:testbox-commands";

	// Default Runner Options
	variables.RUNNER_OPTIONS = {
		"reporter"    : "json",
		"recurse"     : true,
		"bundles"     : "",
		"directory"   : "",
		"labels"      : "",
		"excludes"    : "",
		"testBundles" : "",
		"testSuites"  : "",
		"testSpecs"   : "",
		"verbose"     : false
	};

	/**
	 * Ability to execute TestBox tests
	 *
	 * @runner      The URL or shortname of the runner to use, if it uses a short name we look in your box.json
	 * @bundles     The path or list of paths of the spec bundle CFCs to run and test
	 * @directory   The directory mapping to test: directory = the path to the directory using dot notation (myapp.testing.specs)
	 * @recurse     Recurse the directory mapping or not, by default it does
	 * @reporter    The type of reporter to use for the results, by default is uses our 'simple' report. You can pass in a core reporter string type or a class path to the reporter to use.
	 * @labels      The list of labels that a suite or spec must have in order to execute.
	 * @excludes    The list of labels that a suite or spec must not have in order to execute.
	 * @options     Add adhoc URL options to the runner as options:name=value options:name2=value2
	 * @testBundles A list or array of bundle names that are the ones that will be executed ONLY!
	 * @testSuites  A list of suite names that are the ones that will be executed ONLY!
	 * @testSpecs   A list of test names that are the ones that will be executed ONLY!
	 * @outputFile  We will store the results in this output file as well as presenting it to you.
	 * @outputFormats A list of output reporter to produce using the runner's JSON results only. Available formats are: json,xml,junit,antjunit,simple,dot,doc,min,mintext,doc,text,tap,codexwiki
	 * @verbose Display extra details including passing and skipped tests.
	 * @testboxUseLocal When using outputformats, prefer testbox installation in current working directory over bundled version.
	 **/
	function run(
		string runner = "",
		string bundles,
		string directory,
		boolean recurse,
		string reporter,
		string labels,
		string excludes,
		struct options = {},
		string testBundles,
		string testSuites,
		string testSpecs,
		string outputFile,
		string outputFormats="",
		boolean verbose,
		boolean testboxUseLocal=false
	){
		// Ensure TestBox For reporting and conversions
		ensureTestBox( arguments.testboxUseLocal );

		// Discover runner Url
		arguments.testboxUrl = discoverRunnerUrl( arguments.runner );

		// Incorporate runner options
		arguments.testboxUrl = addRunnerOptions( argumentCollection=arguments );

		// Advise we are running
		print.boldGreenLine( "Executing tests #testboxUrl# please wait..." ).toConsole();

		// run it now baby!
		try {
			// Throw on error means this command will fail if the actual test runner blows up-- possibly on a compilation issue.
			http url=testBoxURL throwonerror=true result="local.results";
		} catch ( any e ) {
			logger.error( "Error executing tests: #e.message# #e.detail#", e );
			return error(
				"Error executing tests: #CR# #e.message##CR##e.detail##CR##local.results.fileContent ?: ""#"
			);
		}

		// Trim whitespaces
		results.fileContent = trim( results.fileContent );

		/**********************************************************************************
		 * Output To CLI
		 **********************************************************************************/

		// Default is to template our own output based on a JSON response
		if ( variables.RUNNER_OPTIONS.reporter == "json" && isJSON( results.fileContent ) ) {
			var testData = deserializeJSON( results.fileContent );

			// If any tests failed or errored.
			if ( testData.totalFail || testData.totalError ) {
				// Send back failing exit code to shell
				setExitCode( 1 );
			}

			// User our Renderer to publish the nice results
			CLIRenderer.render(
				print,
				testData,
				arguments.verbose ?: boxOptions.verbose ?: true
			);

			// For all other reporters, just dump out whatever we got from the server
		} else {
			results.fileContent = reReplace(
				results.fileContent,
				"[\r\n]+",
				CR,
				"all"
			);

			// Print accordingly to results
			if (
				( results.responseheader[ "x-testbox-totalFail" ] ?: 0 ) eq 0 AND
				( results.responseheader[ "x-testbox-totalError" ] ?: 0 ) eq 0
			) {
				// print OK report
				print.green( " " & results.filecontent );
			} else if ( results.responseheader[ "x-testbox-totalFail" ] gt 0 ) {
				// print Failure report
				setExitCode( 1 );
				print.yellow( " " & results.filecontent );
			} else if ( results.responseheader[ "x-testbox-totalError" ] gt 0 ) {
				// print Failure report
				setExitCode( 1 );
				print.boldRed( " " & results.filecontent );
			}
		}

		/**********************************************************************************
		 * Output Formats to Disk?
		 **********************************************************************************/

		// Do we have output formats? and the main report was json
		if( isJSON( results.fileContent ) && len( arguments.outputFormats ) ){

			print
				.line()
				.blueLine( "Output formats detected (#arguments.outputFormats#), building out reports..." )
				.toConsole();

			buildOutputFormats(
				arguments.outputFile ?: "test-results",
				arguments.outputFormats,
				results.fileContent
			);
		}

		/**********************************************************************************
		 * Legacy reporter output to file: Deprecate Later
		 **********************************************************************************/

		// Do we have an output file
		if ( !isNull( arguments.outputFile ) && !len( arguments.outputFormats ) ) {
			// This will make each directory canonical and absolute
			arguments.outputFile = resolvePath( arguments.outputFile );

			var thisDir = getDirectoryFromPath( arguments.outputFile );
			if ( !directoryExists( thisDir ) ) {
				directoryCreate( thisDir );
			}

			if ( isJSON( results.fileContent ) ) {
				results.fileContent = formatterUtil.formatJSON( results.fileContent );
			}

			// write out the JSON
			fileWrite( arguments.outputFile, results.fileContent );
			print.boldGreenLine( "===> JSON Report written to #arguments.outputFile#!" );
		}
	}

	/**
	 * Add runner options to URL
	 *
	 * @return The incorporated options and testing URL to hit
	 */
	private function addRunnerOptions(){
		// Get testbox options from package descriptor
		var boxOptions = packageService.readPackageDescriptor( getCWD() ).testbox;

		// Build out runner options according to override schema: arguments, descriptor, defaults
		for ( var thisOption in variables.RUNNER_OPTIONS ) {
			// Check argument overrides
			if ( !isNull( arguments[ thisOption ] ) ) {
				arguments.testboxURL &= "&#encodeForURL( thisOption )#=#encodeForURL( arguments[ thisOption ] )#";
			}
			// Check runtime options now
			else if ( boxOptions.keyExists( thisOption ) && len( boxOptions[ thisOption ] ) ) {
				if ( isSimpleValue( boxOptions[ thisOption ] ) ) {
					arguments.testboxURL &= "&#encodeForURL( thisOption )#=#encodeForURL( boxOptions[ thisOption ] )#";
				} else {
					print.yellowLine(
						"Ignoring [testbox.#thisOption#] in your box.json since it's not a string.  We can't append it to a URL like that."
					);
				}
			}
			// Defaults
			else if ( len( variables.RUNNER_OPTIONS[ thisOption ] ) ) {
				arguments.testboxURL &= "&#encodeForURL( thisOption )#=#encodeForURL( variables.RUNNER_OPTIONS[ thisOption ] )#";
			}
		}

		// Get global URL options from box.json
		var extraOptions = boxOptions.options ?: {};
		// Add in command-specific options
		extraOptions.append( arguments.options );
		// Append to URL.
		for ( var opt in extraOptions ) {
			arguments.testboxURL &= "&#encodeForURL( opt )#=#encodeForURL( extraOptions[ opt ] )#";
		}

		return arguments.testboxURL;
	}

	/**
	 * Build output formats
	 *
	 * @runner
	 */
	private function buildOutputFormats( outputFile, outputFormats, rawResults ){
		// Convert results to any output report
		var testbox = new testbox.system.TestBox();
		var testResult = new testbox.system.TestResult();

		// populate the result object from the JSON
		variables.wirebox
			.getObjectPopulator()
			.populateFromStruct(
				target = testResult,
				memento = deserializeJSON( arguments.rawResults )
			);

		// Build out the output formats in async fashion
		arguments.outputFormats
			.listToArray()
			.each( ( format ) => {
				// Build out the targetFile
				var targetFile = getCWD() & outputFile & getOutputExtension( arguments.format );
				// write out the JSON
				fileWrite(
					targetFile,
					testbox
						.buildReporter( arguments.format )
						.runReport(
							results 	= testResult,
							testbox 	= testbox,
							options 	= {},
							justReturn 	= true
						)
				);
				print.blueLine( "=> #arguments.format# : #targetFile#" ).toConsole();
			}, true );
	}

	/**
	 * Get the reporter output extension
	 *
	 * @format The included format
	 */
	private function getOutputExtension( required format ){
		switch ( arguments.format ) {
			case "xml" : {
				return ".xml";
			}
			case "junit": case "antjunit" : {
				return "-junit.xml";
			}
			case "simple" : case "dot" : case "min": case "mintext": case "doc": {
				return "-#arguments.format#.html";
			}
			case "text": {
				return ".txt";
			}
			case "tap": {
				return ".tap";
			}
			case "codexwiki": {
				return ".md";
			}
			default : {
				return ".json";
			}
		}
	}

	/**
	 * Discover the testbox runner URL from
	 * 1) Passed argument
	 * 2) box.json descriptor
	 * 3) Current server descriptor
	 *
	 * @runner The runner argument
	 */
	private function discoverRunnerUrl( runner ){
		// If a URL is passed, used it as an override
		if ( left( arguments.runner, 4 ) == "http" || left( arguments.runner, 1 ) == "/" ) {
			if ( !find( "?", arguments.runner ) ) {
				arguments.runner &= "?";
			}
			return arguments.runner;
		}

		// Get Runner from from the box.json
		var runnerUrl = variables.testingService.getTestBoxRunner( getCWD(), arguments.runner );

		// Validate runner
		if ( !len( runnerUrl ) ) {
			var boxJSON       = variables.packageService.readPackageDescriptor( getCWD() );
			var boxJSONRunner = boxJSON.testbox.runner ?: "";
			return error(
				"[#arguments.runner#] it not a valid runner in your box.json. Runners found are: #boxJSONRunner.toString()#"
			);
		}

		// Resolve relative URI, and match to the server defined in this package
		if ( left( runnerUrl, 1 ) == "/" ) {
			var serverDetails = variables.serverService.resolveServerDetails( {} );
			var serverInfo    = serverDetails.serverInfo;

			if ( serverDetails.serverIsNew ) {
				error(
					"The test runner we found [#runnerUrl#] looks like partial URI, but we can't find any servers in this directory. Please give us a full URL."
				);
			} else {
				runnerUrl = ( serverInfo.SSLEnable ? "https://" : "http://" ) & "#serverInfo.host#:#serverInfo.port##runnerUrl#";
			}
		}

		// If we failed to find a URL, throw an error
		if ( left( runnerUrl, 4 ) != "http" ) {
			return error( "[#runnerUrl#] it not a valid URL, or does not match a runner slug in your box.json." );
		}

		if ( !find( "?", runnerUrl ) ) {
			runnerUrl &= "?";
		}

		return runnerUrl;
	}

	/**
	 * Ensure that TestBox is installed
	 */
	private function ensureTestBox( boolean testboxUseLocal = false ){
		if( testboxUseLocal ) {
			var targetPath = resolvePath( 'testbox' );
			if( !directoryExists( targetPath ) ) {
				error( "Uh-oh, you've asked to use a local copy of TestBox, but [#targetPath#] doesn't exist.", "Do you need to run [box install]?");
			}
		} else  {
			var targetPath = variables.moduleConfig.path & "/testbox";
			
		}

		// Add our mapping
		variables.fileSystemUtil.createMapping( "/testbox", targetPath );
	}

}

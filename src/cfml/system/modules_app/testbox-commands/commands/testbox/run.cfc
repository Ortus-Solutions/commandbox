/**
 * Executes TestBox runners via HTTP/S.  By default, the "testbox.runner" property will be read from your box.json.   
* .
* {code:bash}
* testbox run
* {code}   
* .
* You can also specify the URL manually
* {code:bash}
* testbox run "http://localhost:8080/tests/runner.cfm"
* {code}
*
 **/
component {
	
	// DI
	property name="packageService" 	inject="PackageService";
	property name="testingService" 	inject="TestingService@testbox-commands";
	property name="CLIRenderer" 	inject="CLIRenderer@testbox-commands";

	/**
	* Ability to execute TestBox tests
	* @runner      The URL or shortname of the runner to use, if it uses a short name we look in your box.json
	* @bundles     The path or list of paths of the spec bundle CFCs to run and test
	* @directory   The directory mapping to test: directory = the path to the directory using dot notation (myapp.testing.specs)
	* @recurse     Recurse the directory mapping or not, by default it does
	* @reporter    The type of reporter to use for the results, by default is uses our 'simple' report. You can pass in a core reporter string type or a class path to the reporter to use.
	* @labels      The list of labels that a suite or spec must have in order to execute.
	* @options     A JSON struct literal of configuration options that are optionally used to configure a runner.
	* @testBundles A list or array of bundle names that are the ones that will be executed ONLY!
	* @testSuites  A list of suite names that are the ones that will be executed ONLY!
	* @testSpecs   A list of test names that are the ones that will be executed ONLY!
	* @outputFile  We will store the results in this output file as well as presenting it to you.
	* @verbose Display extra details inlcuding passing and skipped tests.  
	**/
	function run(
		string runner="",
		string bundles,
		string directory,
		boolean recurse,
		string reporter="",
		string labels,
		string options,
		string testBundles,
		string testSuites,
		string testSpecs,
		string outputFile,
		boolean verbose=true
	){
		var runnerURL 	= '';

		// If a URL is passed, used it as an override
		if( left( arguments.runner, 4 ) == 'http' ) {
			runnerURL = arguments.runner;
		// Otherwise, try to get one from box.json
		} else {
			runnerURL = testingService.getTestBoxRunner( getCWD(), arguments.runner );
			// Validate runner
			if( !len( runnerURL ) ){
				return error( '(#arguments.runner#) it not a valid runner in your box.json. Runners found are: #packageService.readPackageDescriptor( getCWD() ).testbox.runner.toString()#' );
			}
		}

		// If we failed to find a URL, throw an error
		if( left( runnerURL, 4 ) != 'http' ) {
			return error( '[#runnerURL#] it not a valid URL, or does not match a runner slug in your box.json.' );
		}

		// Default runner builder
		var testboxURL = runnerURL & "?";
		
		// Runner options overridable by arguments and box options
		var RUNNER_OPTIONS = {
			"reporter"	    : "json",
			"recurse"	    : true,
			"bundles"	    : "",
			"directory"	    : "",
			"labels"	    : "",
			"testBundles"	: "",
			"testSuites"	: "",
			"testSpecs" 	: ""
		};

		// Get testbox options from package descriptor
		var boxOptions 	= packageService.readPackageDescriptor( getCWD() ).testbox;
		// Build out runner options
		for( var thisOption in RUNNER_OPTIONS ){
			// Check argument overrides
			if( !isNull( arguments[ thisOption ] ) && len( arguments[ thisOption ] ) ){
				testboxURL &= "&#thisOption#=#arguments[ thisOption ]#";
			} 
			// Check runtime options now
			else if( boxOptions.keyExists( thisOption ) && len( boxOptions[ thisOption ]) ){
				testboxURL &= "&#thisOption#=#boxOptions[ thisOption ]#";
			} 
			// Defaults
			else if( len( RUNNER_OPTIONS[ thisOption ] ) ) {
				testboxURL &= "&#thisOption#=#RUNNER_OPTIONS[ thisOption ]#";
			}
		}

		// Advise we are running
		print.boldCyanLine( "Executing tests via #testBoxURL#, please wait..." )
			.toConsole();

		// run it now baby!
		try{
			// Throw on error means this command will fail if the actual test runner blows up-- possibly on a compilation issue.
			Http url=testBoxURL throwonerror=true result='local.results' ;			
		} catch( any e ){			
			logger.error( "Error executing tests: #e.message# #e.detail#", e );
			return error( 'Error executing tests: #CR# #e.message##CR##e.detail##CR##local.results.fileContent ?: ''#' );
		}

		// Do we have an output file
		if( !isNull( arguments.outputFile ) ){
			// This will make each directory canonical and absolute
			arguments.outputFile = fileSystemUtil.resolvePath( arguments.outputFile );
			// write it
			fileWrite( arguments.outputFile, results.fileContent );
			print.boldGreenLine( "Report written to #arguments.outputFile#!" );
		}
		
		results.fileContent = trim( results.fileContent );
		
		// Default is to template our own output based on a JSON reponse
		if( RUNNER_OPTIONS.reporter == 'json' && isJSON( results.fileContent ) ) {
			
			var testData = deserializeJSON( results.fileContent );
			
			// If any tests failed or errored.
			if( testData.totalFail || testData.totalError ) {
				// Send back failing exit code to shell
				setExitCode( 1 );
			} 
			
			CLIRenderer.render( print, testData, verbose );
									
			//systemOutput( getINstance( 'formatter' ).formatJSON( testData ) );
			
		// For all other reporters, just dump out whatever we got from the server
		} else {
			
			results.fileContent = reReplace( results.fileContent, '[\r\n]+', CR, 'all' );
		
			// Print accordingly to results
			if( ( results.responseheader[ "x-testbox-totalFail" ]  ?: 0 ) eq 0 AND
				( results.responseheader[ "x-testbox-totalError" ] ?: 0 ) eq 0 ){
				// print OK report
				print.green( " " & results.filecontent );
			} else if( results.responseheader[ "x-testbox-totalFail" ] gt 0 ){
				// print Failure report
				setExitCode( 1 );
				print.yellow( " " & results.filecontent );
			} else if( results.responseheader[ "x-testbox-totalError" ] gt 0 ){
				// print Failure report
				setExitCode( 1 );
				print.boldRed( " " & results.filecontent );
			}

			
		}
				
	}

}
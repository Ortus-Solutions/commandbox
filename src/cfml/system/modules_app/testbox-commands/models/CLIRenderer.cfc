/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I render TestBox data out for the CLI
*/
component {

 	variables.HEADER_CELL_CHARS = 7;
 	variables.COLOR = {
 		PASS : 'green',
 		SKIP : 'yellow',
 		ERROR : 'boldRed',
 		FAIL : 'boldRed'
 	};
 	variables.MAX_STACKTRACES = 5;

	/**
	* @print a print buffer to use
	* @testData test results from TestBox
	* @verbose Display information about passing and skipped specs
	*/
	function render( print, testData, verbose ) {

		var thisColor = getAggregatedColor( testData.totalError, testData.totalFail, 0 );
		print
			.line( "TestBox " & ( !isNull( testData.version ) ? "v#testData.version#" : "" ) )
			.line( "---------------------------------------------------------------------------------", thisColor )
			.line( "| Passed  | Failed  | Errored | Skipped | Time    | Bundles | Suites  | Specs   |", thisColor )
			.line( "---------------------------------------------------------------------------------", thisColor )
			.line( "| #headerCell(testData.totalPass)# | #headerCell(testData.totalFail)# | #headerCell(testData.totalError)# | #headerCell(testData.totalSkipped)# | #headerCell(testData.totalDuration & ' ms')# | #headerCell(testData.totalBundles)# | #headerCell(testData.totalSuites)# | #headerCell(testData.totalSpecs)# |", thisColor )
			.line( "---------------------------------------------------------------------------------", thisColor );

		if ( arrayLen( testData.labels ) ) {
			print.line( "Labels Applied: #arrayToList( testData.labels )#", thisColor );
		}
		if( isDefined( 'testData.coverage.enabled' ) && testData.coverage.enabled ) {
			print.line( "Coverage: #testData.coverage.data.stats.totalCoveredLines# / #testData.coverage.data.stats.totalExecutableLines# LOC (#numberFormat( testData.coverage.data.stats.percTotalCoverage*100, '9.9' )#%) Covered", thisColor );
			if( len( testData.coverage.data.sonarQubeResults ) ) {
				print.line( "Coverage: SonarQube file written to [#testData.coverage.data.sonarQubeResults#]", thisColor );
			}
			if( len( testData.coverage.data.browserResults ) ) {
				print.line( "Coverage: Browser written to [#testData.coverage.data.browserResults#]", thisColor );
			}
		}

		var didPrint = false;
		for ( thisBundle in testData.bundleStats ) {

			if ( ( thisBundle.totalFail + thisBundle.totalError ) == 0  && !verbose) {
				continue;
			}

			var thisColor = getAggregatedColor( thisBundle.totalError, thisBundle.totalFail, 0 );
			print
				.line("=================================================================================", thisColor )
				.line( "#thisBundle.path# (#thisBundle.totalDuration# ms) [Suites/Specs: #thisBundle.totalSuites#/#thisBundle.totalSpecs#]", thisColor )
				.line( "[Passed: #thisBundle.totalPass#] [Failed: #thisBundle.totalFail#] [Errors: #thisBundle.totalError#] [Skipped: #thisBundle.totalSkipped#]", thisColor )
				.line( "---------------------------------------------------------------------------------", thisColor );

			// Check if the bundle threw a global exception
			if ( !isSimpleValue( thisBundle.globalException ) ) {

				print.line("GLOBAL BUNDLE EXCEPTION", COLOR.ERROR )
					.line( "-> #thisBundle.globalException.type#:#thisBundle.globalException.message#:#thisBundle.globalException.detail#", COLOR.ERROR )
					.line( "---------------------------------------------------------------------------------", COLOR.ERROR );

				// ACF has an array for the stack trace
				if( isSimpleValue( thisBundle.globalException.stacktrace ) ) {
					print
						.line( "STACKTRACE", COLOR.ERROR )
						.line( "---------------------------------------------------------------------------------", COLOR.ERROR )
						.line( "#thisBundle.globalException.stacktrace#", COLOR.ERROR )
						.line( "---------------------------------------------------------------------------------", COLOR.ERROR )
						.line( "END STACKTRACE", COLOR.ERROR );
				}

				print.line( "---------------------------------------------------------------------------------", COLOR.ERROR );
			}

			// Generate reports for each suite
			for( var suiteStats in thisBundle.suiteStats ) {
				didPrint = genSuiteReport( 
					suiteStats  = suiteStats, 
					bundleStats = thisBundle, 
					level       = 0, 
					print       = print, 
					verbose     = verbose 
				);
			}
		}

		// Skip this redundant line if no specs printed above in the previous suite
		if( didPrint ) {
			print.line("---------------------------------------------------------------------------------", thisColor );
		}

		// If verbose print the final footer report
		if( verbose ) {
			print
				.text( "Passed", COLOR.PASS ).text( " || " )
				.text( "Skipped", COLOR.SKIP ).text( " || " )
				.text( "Exception/Error", COLOR.ERROR ).text( " || " )
				.text( "Failure", COLOR.FAIL )
				.line();
		}

	}

	/**
	 * Recursive Output for suites
	 * @suiteStats Suite stats
	 * @bundleStats Bundle stats
	 * @level Generation level
	 * @print The print Buffer
	 * @verbose The verbose indicator
	 */
	function genSuiteReport( 
		required suiteStats, 
		required bundleStats, 
		level="0", 
		required print, 
		required verbose 
	){

		// Return if not in verbose mode nd no errors
		if ( ( arguments.suiteStats.totalFail + arguments.suiteStats.totalError ) == 0  && !verbose) {
			return false;
		}

		var tabs = repeatString( "    ", arguments.level );

		print.line( 
			"#tabs#+#arguments.suiteStats.name# #chr( 13 )#", 
			getAggregatedColor( arguments.suiteStats.totalError, arguments.suiteStats.totalFail, ( arguments.suiteStats.status == 'skipped' ? 1 : 0 ) )
		);

		var printedAtLeastOneLine = false;
		for ( local.thisSpec in arguments.suiteStats.specStats ) {

			// Continue if no eception and not in verbose mode
			if ( ListFindNoCase( "failed,exception,error", local.thisSpec.status ) == 0 && !verbose ) {
				continue;
			}

			printedAtLeastOneLine = true;
			var thisColor = getAggregatedColor( ( local.thisSpec.status == "error" ? 1 : 0 ), ( local.thisSpec.status == "failed" ? 1 : 0 ), ( local.thisSpec.status == "skipped" ? 1 : 0 ) );
			
			print.line("#repeatString( "    ", arguments.level+1 )##local.thisSpec.name# (#local.thisSpec.totalDuration# ms) #chr( 13 )#", thisColor );

			if ( local.thisSpec.status == "failed" ) {
				print.line("#repeatString( "    ", arguments.level+2 )#-> Failure: #local.thisSpec.failMessage##chr( 13 )#", COLOR.FAIL );
			}

			if ( local.thisSpec.status == "error" ) {
				
				print.line( 
					"#repeatString( "    ", arguments.level+2 )#-> Error: #local.thisSpec.error.message##chr( 13 )#", 
					COLOR.ERROR 
				);
				
				var errorStack = [];

				// If there's a tag context, show the file name and line number where the error occurred
				if( isDefined( 'local.thisSpec.error.tagContext' ) && isArray( local.thisSpec.error.tagContext ) && local.thisSpec.error.tagContext.len() ) {
					errorStack = thisSpec.error.tagContext;
				// For some reason, the tag context sometimes is here.  Isn't consistency great??
				} else if( isDefined( 'local.thisSpec.failOrigin' ) && isArray( local.thisSpec.failOrigin ) && local.thisSpec.failOrigin.len() ) {
					errorStack = thisSpec.failOrigin;
				} 

				// Show at least 5 stack origins, 1 is not enough for debugging.
				errorStack.each( function( item, index ){
					if( index <= variables.MAX_STACKTRACES ){
						print.line( 
							"#repeatString( "    ", level + 2 )#-> at #item.template#:#item.line# #chr( 13 )##chr( 13 )#", 
							COLOR.ERROR 
						);
					}
				} );
			}
		}

		// Nested Suites?
		if ( arrayLen( arguments.suiteStats.suiteStats ) ) {
			for ( local.nestedSuite in arguments.suiteStats.suiteStats ) {
				var didPrint = genSuiteReport( local.nestedSuite, arguments.bundleStats, arguments.level+1, print, verbose )
				printedAtLeastOneLine = printedAtLeastOneLine || didPrint;
			}
		}

		return printedAtLeastOneLine;
	}

	/**
	 * Create a header cell
	 * @text The header text
	 */
	private function headerCell( required text ) {
		return left( arguments.text & repeatString( " ", HEADER_CELL_CHARS ), HEADER_CELL_CHARS );
	}

	/**
	 * Get aggregate color for display
	 * @errors number of errors
	 * @failures number of failures
	 * @skips number of skipped specs
	 */
	private function getAggregatedColor( errors=0, failures=0, skips=0 ) {
		if( errors ) {
			return COLOR.ERROR;
		} else if( failures ) {
			return COLOR.FAIL;
		} else if( skips ) {
			return COLOR.SKIP;
		} else{
			return COLOR.PASS;
		}
	}

}

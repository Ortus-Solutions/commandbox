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

	/**
	* @print a print buffer to use
	* @testData test results from TestBox
	* @verbose Display information about passing and skipped specs
	*/
	function render( print, testData, verbose ) {
	
		var thisColor = getAggregatedColor( testData.totalError, testData.totalFail, 0 );
		print
			.line("TestBox " & ( !isNull( testData.version ) ? "v#testData.version#" : "" ) )
			.line( "---------------------------------------------------------------------------------", thisColor )
			.line( "| Passed  | Failed  | Errored | Skipped | Time    | Bundles | Suites  | Specs   |", thisColor )
			.line( "---------------------------------------------------------------------------------", thisColor )
			.line( "| #headerCell(testData.totalPass)# | #headerCell(testData.totalFail)# | #headerCell(testData.totalError)# | #headerCell(testData.totalSkipped)# | #headerCell(testData.totalDuration & ' ms')# | #headerCell(testData.totalBundles)# | #headerCell(testData.totalSuites)# | #headerCell(testData.totalSpecs)# |", thisColor )
			.line( "---------------------------------------------------------------------------------", thisColor);
			
		if ( arrayLen( testData.labels ) ) {
			print.line("->[Labels Applied: #arrayToList( testData.labels )#]");
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
			
			if ( !isSimpleValue( thisBundle.globalException ) ) {
	
				print.line("GLOBAL BUNDLE EXCEPTION", COLOR.ERROR )
					.line( "-> #thisBundle.globalException.type#:#thisBundle.globalException.message#:#thisBundle.globalException.detail#", COLOR.ERROR )
					.line( "---------------------------------------------------------------------------------", COLOR.ERROR )
					.line( "STACKTRACE", COLOR.ERROR )
					.line( "---------------------------------------------------------------------------------", COLOR.ERROR )
					.line( "#thisBundle.globalException.stacktrace#", COLOR.ERROR )
					.line( "---------------------------------------------------------------------------------", COLOR.ERROR )
					.line( "END STACKTRACE", COLOR.ERROR )
					.line( "---------------------------------------------------------------------------------", COLOR.ERROR );
			}
			for ( suiteStats in thisBundle.suiteStats ) {
				didPrint = genSuiteReport( suiteStats, thisBundle, 0, print, verbose );
			}
		}
		
		// Skip this redundant line if no specs printed above in the previous suite
		if( didPrint ) {
			print.line("---------------------------------------------------------------------------------", thisColor );			
		}
		
		if( verbose ) {
			print
				.text( "Passed", COLOR.PASS ).text( " || " )
				.text( "Skipped", COLOR.SKIP ).text( " || " )
				.text( "Exception/Error", COLOR.ERROR ).text( " || " )
				.text( "Failure", COLOR.FAIL )
				.line();
		}

	}
			
	//  Recursive Output
	function genSuiteReport(suiteStats, bundleStats, level="0", print, verbose ) {
			
		if ( ( arguments.suiteStats.totalFail + arguments.suiteStats.totalError ) == 0  && !verbose) {
			return false;
		}
		var tabs = repeatString( "    ", arguments.level );
		
		print.line( "#tabs#+#arguments.suiteStats.name# #chr(13)#", getAggregatedColor( arguments.suiteStats.totalError, arguments.suiteStats.totalFail, ( arguments.suiteStats.status == 'skipped' ? 1 : 0 ) ) );
		
		var printedAtLeastOneLine = false;
		for ( local.thisSpec in arguments.suiteStats.specStats ) {
						
			if ( ListFindNoCase("failed,exception,error", local.thisSpec.status) == 0 && !verbose ) {
				continue;
			}

			printedAtLeastOneLine = true;
			var thisColor = getAggregatedColor( ( local.thisSpec.status == "error" ? 1 : 0 ), ( local.thisSpec.status == "failed" ? 1 : 0 ), ( local.thisSpec.status == "skipped" ? 1 : 0 ) );
			print.line("#repeatString( "    ", arguments.level+1 )##local.thisSpec.name# (#local.thisSpec.totalDuration# ms) #chr(13)#", thisColor );
			
			if ( local.thisSpec.status == "failed" ) {
				print.line("#repeatString( "    ", arguments.level+2 )#-> Failure: #local.thisSpec.failMessage##chr(13)#", COLOR.FAIL ); 
			}
			if ( local.thisSpec.status == "error" ) {
				print.line("#repeatString( "    ", arguments.level+2 )#-> Error: #local.thisSpec.error.message##chr(13)#", COLOR.ERROR )
					.line( "#repeatString( "    ", arguments.level+2 )#-> Exception Trace: #local.thisSpec.error.stackTrace# #chr(13)##chr(13)#", COLOR.ERROR );
			}
		}
		if ( arrayLen( arguments.suiteStats.suiteStats ) ) {
			for ( local.nestedSuite in arguments.suiteStats.suiteStats ) {
				var didPrint = genSuiteReport( local.nestedSuite, arguments.bundleStats, arguments.level+1, print, verbose )
				printedAtLeastOneLine = printedAtLeastOneLine || didPrint;
			}
		}
		return printedAtLeastOneLine;
	}
	
	private function headerCell( text ) {
		return Left( arguments.text & RepeatString( " ", HEADER_CELL_CHARS), HEADER_CELL_CHARS);
	}
	
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
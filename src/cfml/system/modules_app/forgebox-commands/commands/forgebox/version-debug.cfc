/**
 * Debug what semantic version range will match on ForgeBox.  Helpful to test before actually installing
 * Provide a ForgeBox install ID in the form of package@version and find out what version of the package that would actually install
 * .
 * {code:bash}
 * forgebox version-debug coldbox@5.x
 * {code}
 * .
 **/
component {

	// DI
	property name="semanticVersion"	inject="semanticVersion@semver";
	property name="endpointService" inject="endpointService";
	property name="configService" inject="configService";

	/**
	* @installID Install ID to test
	* @installID.optionsUDF IDComplete
	* @endpointName Name of endpoint (defaults to "forgebox")
	* @showMatchesOnly True will filter out display of package versions that didnt match sem ver range
	**/
	function run( required string installID, string endpointName, boolean showMatchesOnly=false ) {
		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		try {
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}

		var APIToken = oEndpoint.getAPIToken();
		var forgebox = oEndpoint.getForgeBox();

		var slug = oEndpoint.parseSlug( installID )
		var version = oEndpoint.parseVersion( installID )
		var satisfyingVersion = ''
		print.line( 'Endpoint: #endpointName#' )
			.line( 'Requested Slug: #slug#' )
			.line( 'Requested Version: #version#' )
			.line();
		try {

			print.yellowLine( "Verifying package '#slug#' in #endpointName#, please wait..." ).toConsole();

			var entryData = forgebox.getEntry( slug, APIToken );


			print.yellowLine( 'Package [#slug#] has #entryData.versions.len()# versions.' ).line().toConsole();

			if( !entryData.isActive ) {
				error( 'The #endpointName# entry [#entryData.title#] is inactive.', 'endpointException' );
			}

			var versions = entryData.versions.map( (v)=>v.version );
			var matches = [];
			// If this is an exact version (not a range) just do a simple lookup for it
			if( semanticVersion.isExactVersion( version, true ) ) {
				print.line( 'Requested version [#version#] is an exact version, so no semantic version ranges are begin used, just a direct match.' )
				for( var thisVer in versions ) {
					if( semanticVersion.isEQ( version, thisVer, true ) ) {
						matches.append( thisVer.version );
						print.line( 'Exact match [#thisVer#] found.' )
						satisfyingVersion = thisVer;
						break;
					}
				}
				if( !len( satisfyingVersion ) ) {
					print.redLine( 'Exact version [#version#] not found for package [#slug#].' );
				}
			} else {

				print.line( 'Requested version [#version#] is a semantic range, so searching against #versions.len()# versions for matches.' )
				// For version ranges, do a smart lookup
				versions.sort( function( a, b ) { return semanticVersion.compare( b, a ) } );
				for( var thisVersion in versions ) {
					if( semanticVersion.satisfies( thisVersion, version ) ) {
						matches.append( thisVersion );
					}
				}

				if( matches.len() ) {
					satisfyingVersion = matches[1];
					print.line( 'Found #matches.len()# matches for our version range, so taking the latest one.' )
					//print.line( matches );
				} else if( version == 'stable' && arrayLen( versions ) ) {
					print.line( "The version [stable] doesn't match any avaialble versions, which means all versions are a pre-release, so we'll just grab the latest one (same as [be])." )
					satisfyingVersion = versions[ 1 ];

					matches = v
				} else {
					print.redLine( 'Version [#version#] not found for package [#slug#].' );
				}
			}

			if( len( satisfyingVersion ) ) {
				print.line().boldGreenline( "Version [#satisfyingVersion#] would be chosen for installation." );
			}

		} catch( forgebox var e ) {

			if( e.detail contains 'The entry slug sent is invalid or does not exist' ) {
				error( "#e.message#  #e.detail#" );
			}

			print.redline( "Aww man, #endpointName# ran into an issue.");
			error( "#e.message#  #e.detail#" );

		}

		print.line()
			.line();

		if( showMatchesOnly ) {
			versions = matches;
		}
		// Create table that matches screen width and outputs versions from "lowest" to "highest" down the columns from left to right
		var numVersions = versions.len();
		if( numVersions ) {
			var versions = versions.reverse()
			var widestVersion = versions.map( (v)=>len( v ) ).max();
			var colWdith = widestVersion + 4;
			var termWidth = shell.getTermWidth()-1;
			var numCols = termWidth\colWdith;
			var numRows = ceiling( numVersions/numCols );

			loop from=1 to=numRows index="local.row" {
				loop from=1 to=numCols index="local.col" {
					var thisIndex = row+((col-1)*numRows);
					var format='grey';
					if( thisIndex > numVersions ) {
						var thisVersion = '';
					} else {
						var thisVersion = versions[thisIndex];
						if( satisfyingVersion == thisVersion ) {
							format = 'boldwhiteOnGreen';
						} else if ( matches.find( thisVersion ) ) {
							format = 'boldWhite';
						}
					}
					print.text( padRight( thisVersion, colWdith ), format );
				}
				print.line()
			}
			print.line()
				.greyLine( 'Unmatched Version' )
				.boldWhiteLine( 'Version matching semver range' )
				.boldwhiteOnGreenLine( 'Chosen Version' );

		}
	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}


	// Auto-complete list of IDs
	function IDComplete( string paramSoFar ) {
		// Only hit forgebox if they've typed something.
		if( !len( trim( arguments.paramSoFar ) ) ) {
			return [];
		}
		try {


			var endpointName = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

			try {
				var oEndpoint = endpointService.getEndpoint( endpointName );
			} catch( EndpointNotFound var e ) {
				error( e.message, e.detail ?: '' );
			}

			var forgebox = oEndpoint.getForgebox();
			var APIToken = oEndpoint.getAPIToken();

			// Get auto-complete options
			return forgebox.slugSearch( searchTerm=arguments.paramSoFar, APIToken=APIToken );
		} catch( forgebox var e ) {
			// Gracefully handle ForgeBox issues
			print
				.line()
				.yellowLine( e.message & chr( 10 ) & e.detail )
				.toConsole();
			// After outputting the message above on a new line, but the user back where they started.
			getShell().getReader().redrawLine();
		}
		// In case of error, break glass.
		return [];
	}


    /**
     * Adds characters to the right of a string until the string reaches a certain length.
     * If the text is already greater than or equal to the maxWidth, the text is returned unchanged.
     * @text The text to pad.
     * @maxWidth The number of characters to pad up to.
     * @padChar The character to use to pad the text.
     */
	private string function padRight( required string text, required numeric maxWidth, string padChar = " " ) {
		var textLength = len( arguments.text );
		if ( textLength == arguments.maxWidth ) {
			return arguments.text;
		} else if( textLength > arguments.maxWidth ) {
			if( arguments.maxWidth < 4 ) {
				return left( text, arguments.maxWidth );
			} else {
				return left( text, arguments.maxWidth-3 )&'...';
			}
		}
		arguments.text &= repeatString( arguments.padChar, arguments.maxWidth-textLength );
		return arguments.text;
	}

}

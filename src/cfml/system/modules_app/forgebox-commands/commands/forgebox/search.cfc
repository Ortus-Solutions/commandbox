/**
 * Search for ForgeBox entries by keyword.  Search is case-insensitive and will match text anywhere in the
 * title, summary, or author name.
 * .
 * {code:bash}
 * forgebox search blogCFC
 * {code}
 * .
 **/
component {

	// DI
	property name="forgeBox"		inject="ForgeBox";
	property name="semanticVersion"	inject="semanticVersion@semver";

	/**
	* @searchText.hint Text to search on
	**/
	function run( searchText ) {

		// Default parameter
		arguments.searchText = arguments.searchText ?: '';

		try {

				var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );

				// Get the entries
				var entries = forgebox.getEntries( searchTerm = arguments.searchText, APIToken=APIToken );

				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description

				print.line();
				for( var entry in entries.results ) {
					entry.versions.sort( function( a, b ) { return semanticVersion.compare( b.version, a.version ) } );
					if ( entry.isPrivate ) {
						print.boldWhiteOnRed( "Private" ).text( "   " );
					}
					print.blackOnWhite( ' #entry.title# ' )
						.boldText( '   ( #entry.user.fname# #entry.user.lname# )' )
						.boldGreenLine( '   Rating: #repeatString( '*', val( entry.avgRating ) )#' )
						.text( 'Versions: ' );
						
					// TODO: Consolidate this with identical logic in "forgebox show"
					var prevMajor = 0;
					if( entry.versions.len() ) {
						prevMajor = val( entry.versions[ 1 ].version.listGetAt( 1, '.' ) );
					}
					var majorCount = 0;
					var versionLine = '';
					var lines = 0;
					var versionsSkipped = 0;
					for( var ver in entry.versions ) {
						var major = val( ver.version.listGetAt( 1, '.' ) );
						if( major == 0 && ver.version.listlen( '.' ) > 1 ) {
							major = val( ver.version.listGetAt( 2, '.' ) );						
						}
						if( major != prevMajor ) {
							if( lines > 0 ) { print.text( '          ' ); }
							print.line( versionLine & ( versionsSkipped > 0 ? ' ( #versionsSkipped# more...)' : '' ) );
							majorCount = 0;
							versionLine = '';
							versionsSkipped = 0;
							lines++;
						}
						majorCount++;
						if( majorCount <= 5 ) {
							versionLine = versionLine.listAppend( ' ' & ver.version );
						} else {
							versionsSkipped++;
						}
						prevMajor = major;
					}
					if( len( versionLine ) ) {
						if( lines > 0 ) { print.text( '          ' ); }
						print.line( versionLine & ( versionsSkipped > 0 ? ' ( #versionsSkipped# more...)' : '' ) );
					}

					
					print
						.line( 'Type: #entry.typeName#' )
						.line( 'Slug: "#entry.slug#"' )
						.line( 'ForgeBox URL: #forgebox.getEndpointURL()#/view/#entry.slug#' )
						.yellowline( '#left( entry.summary, 200 )#' )
						.line()
						.line();
				}

				print.line();
				print.boldCyanline( "  Showing #entries.count# of #entries.totalRecords# record#( entries.count == 1 ? '' : 's' )#." );

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "slug not found"
			return error( '#e.message##CR##e.detail#' );
		}

	}

}

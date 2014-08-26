/**
 * Search for ForgeBox entries by keyword.  Search is case-insensitive and will match text anywhere in the 
 * title, summary, or author name.
 * .
 * {code:bash}
 * forgebox search blogCFC
 * {code}
 * .
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	// DI
	property name="forgeBox" inject="ForgeBox";
	
	/**
	* Constructor
	*/
	function init() {
		return super.init( argumentCollection = arguments );
	}
	
	/**
	* @searchText.hint Text to search on
	**/
	function run( searchText ) {
					
		// Default parameter
		arguments.searchText = arguments.searchText ?: '';
			
		try {
				
				// Get the entries
				var entries = forgebox.getEntries();
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description
				
				print.line();
				var activeCount = 0;
				for( var entry in entries ) {
					if( val( entry.isactive )
					&& (
						   entry.title contains arguments.searchText
						|| entry.fname contains arguments.searchText
						|| entry.lname contains arguments.searchText
						|| entry.typeName contains arguments.searchText
						|| entry.summary contains arguments.searchText
					) ) {
						activeCount++;
						print.blackOnWhite( ' #entry.title# ' ); 
							print.boldText( '   ( #entry.fname# #entry.lname# )' );
							print.boldGreenLine( '   #repeatString( '*', val( entry.entryRating ) )#' );
						print.line( 'Type: #entry.typeName#' );
						print.line( 'Slug: "#entry.slug#"' );
						print.Yellowline( '#left( entry.summary, 200 )#' );
						print.line();
						print.line();
					}
				}
						
				print.line();
				print.boldCyanline( '  Found #activeCount# record#(activeCount == 1 ? '': 's')#.' );
						
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "slug not found"
			return error( '#e.message##CR##e.detail#' );
		}
		
	}

} 
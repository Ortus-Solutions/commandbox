/**
 * This command will allow you to search for ForgeBox entires.  You can sort entires by most popular, recently updated, and newest.  
 * You can also filter for specific entry types such as cachebox, interceptors, modules, logbox, etc.
 * There are parameters to paginate results or you can pipe the output of this command into the "more" command like so:
 * forgebox show popular | more
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	// Create our ForgeBox helper
	variables.forgebox = new commandbox.system.util.ForgeBox();
	// Get and cache a list of valid ForgeBox types
	variables.forgeboxTypes = forgebox.getTypes();
	variables.forgeboxOrders =  forgebox.ORDER;
	
	/**
	* @orderBy.hint How to order results. Possible values are popular, new, and recent 
	* @type.hint Name or slug of type to filter by. See possible types with "forgebox types command"
	* @startRow.hint Row to start returning records on
	* @maxRows.hint Number of records to return
	* @entry.hint Name of a specific ForgeBox entry slug to show.
	* 
	**/
	function run( 
				orderBy='popular',
				type,
				number startRow,
				number maxRows,
				entry ) {
					
		// Default parameters
		type = type ?: '';
		startRow = startRow ?: 1;
		maxRows = maxRows ?: 0;
		entry = entry ?: '';
		
		// Validate orderBy
		var orderLookup = forgeboxOrders.findKey( orderBy ); 
		if( !orderLookup.len() ) {
			error( 'orderBy value of [#orderBy#] is invalid.  Valid options are [ #lcase( listChangeDelims( forgeboxOrders.keyList(), ', ' ) )# ]' );
		}
		
		// Validate Type if we got one
		var typeLookup = '';
		if( len( type ) ) {
			// See if they entered a type name or slug
			for( var thistype in forgeboxTypes ) {
				if( thisType.typeName == type || thisType.typeSlug == type ) {
					typeLookup = thisType.typeSlug;
					break;
				}
			}
			// Were we able to resolve what they typed in?
			if( !len( typeLookup ) ) {
				error( 'Type value of [#type#] is invalid. See possible types with "forgebox types command".' );
			}
		}
		if( hasError() ){
			return;
		}
		
		try {
			
			// We're displaying a single entry	
			if( len( entry ) ) {
	
				var entryData = forgebox.getEntry( entry );
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email
								
				if( !val( entryData.isActive ) ) {
					error( 'Thr ForgeBox entry [#entry#] is inactive.' );
				}
				
				
				print.line();
				print.blackOnWhite( ' #entryData.title# ' ); 
					print.boldText( '   ( #entryData.fname# #entryData.lname#, #entryData.email# )' );
					print.boldGreenLine( '   #repeatString( '*', val( entryData.entryRating ) )#' );
				print.line();
				print.line( 'Type: #entryData.typeName#' );
				print.line( 'Slug: "#entryData.slug#"' );
				print.line( 'Summary: #entryData.summary#' );
				print.line( 'Created On: #entryData.createdate#' );
				print.line( 'Updated On: #entryData.updateDate#' );
				print.line( 'Version: #entryData.version#' );
				print.line( 'Home URL: #entryData.homeURL#' );
				print.line( 'Hits: #entryData.hits#' );
				print.line( 'Downloads: #entryData.downloads#' );
				print.line();
				
				print.yellowLine( #ANSIUtil.HTML2ANSI( entryData.description )# );
				
				
			// List of entries
			} else {
				
				// Get the entries
				var entries = forgebox.getEntries( orderBy, maxRows, startRow, typeLookup );
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description
				
				print.line();
				var activeCount = 0;
				for( var entry in entries ) {
					if( val( entry.isactive ) ) {
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
				
			} // end single entry check
				
		} catch( forgebox var e ) {
			// This can include "expected" errors such as "slug not found"
			return error( '#e.message##CR##e.detail#' );
		}
		
	}

} 
/**
 * Show forgeBox entries by slug or type.  You can sort entires by most popular, recently updated, and newest.  
 * You can also filter for specific entry types such as cachebox, interceptors, modules, logbox, etc.
 * Pro Tip: The first parameter will accept a type or a slug.
 * .
 * Show details for a specifig entry
 * {code:bash}
 * forgebox show coldbox-platform
 * {code}
 * .
 * Show entries of a given type. Use the "forgebox types" command to see available options
 * {code:bash}
 * forgebox show plugins
 * {code}
 * .
 * Sort 10 newest entries
 * {code:bash}
 * forgebox show orderby=new maxRows=10
 * {code}
 * .
 * Show sorted entries by type
 * {code:bash}
 * forgebox show new plugins
 * forgebox show popular modules
 * forgebox show recent commandbox-commands
 * {code}
 * .
 * There are parameters to paginate results or you can pipe the output of this command into the "more" command like so:
 * {code:bash}
 * forgebox show popular | more
 * {code}
 *
 **/
component aliases="show" {
	
	// DI
	property name="forgeBox" inject="ForgeBox";
	property name="semanticVersion"		inject="semanticVersion";
	
	function onDIComplete() {
		variables.forgeboxOrders =  forgebox.ORDER;
	}
	
	/**
	* @orderBy.hint How to order results. Possible values are popular, new, installs, recent or a specific ForgeBox type
	* @orderBy.optionsUDF orderByComplete
	* @type.hint Name or slug of type to filter by. See possible types with "forgebox types command"
	* @type.optionsUDF typeComplete
	* @startRow.hint Row to start returning records on
	* @maxRows.hint Number of records to return
	* @slug.hint Slug of a specific ForgeBox entry to show.
	* 
	**/
	function run( 
		orderBy='popular',
		type,
		number startRow,
		number maxRows,
		slug 
	){
		
		print.yellowLine( "Contacting ForgeBox, please wait..." ).toConsole();
				
		// Default parameters
		arguments.type 		= arguments.type ?: '';
		arguments.startRow 	= arguments.startRow ?: 1;
		arguments.maxRows 	= arguments.maxRows ?: 0;
		arguments.slug 		= arguments.slug ?: '';
		var typeLookup = '';
		
		// Validate orderBy
		var orderLookup = forgeboxOrders.findKey( orderBy ); 
		if( !orderLookup.len() ) {
			// If there is a type supplied, quit here
			if( len( type ) ){
				error( 'orderBy value of [#orderBy#] is invalid.  Valid options are [#lcase( listChangeDelims( forgeboxOrders.keyList(), ', ' ) )#]' );
			// Maybe they entered a type as the first param
			} else {
				// See if it's a type
				typeLookup = lookupType( orderBy );
				// Nope, keep searching
				if( !len( typeLookup ) ) {
					// If there's not a slug supplied, see if that works
					if( !len( slug ) ) {
						try {
							var entryData = forgebox.getEntry( orderBy );
							slug = orderBy;		
						} catch( any e ) {
							if( e.detail contains 'The entry slug sent is invalid' ) {
								error( 'Parameter [#orderBy#] isn''t a valid orderBy, type, or slug.  Valid orderBys are [#lcase( listChangeDelims( forgeboxOrders.keyList(), ', ' ) )#] See possible types with "forgebox types".' );								
							} else {
								rethrow;								
							}
						}
					} 
				}		
			}
		}
		
		// Validate Type if we got one
		if( len( type ) ) {
			typeLookup = lookupType( type );
			
			// Were we able to resolve what they typed in?
			if( !len( typeLookup ) ) {
				error( 'Type value of [#type#] is invalid. See possible types with "forgebox types".' );
			}
		}

		// error check
		if( hasError() ){
			return;
		}
		
		try {
			
			// We're displaying a single entry	
			if( len( slug ) ) {
	
				// We might have gotten this above
				var entryData = entryData ?: forgebox.getEntry( slug );
				// numberOfRatings,boxjson,isActive,typeName,version,hits,sourceURL,slug,createdDate,typeSlug,downloads,updatedDate,entryID,
				// ratings,versions,avgRating,downloadURL,changelog,installs,title,user,description,summary,homeURL
								
				if( !val( entryData.isActive ) ) {
					error( 'The ForgeBox entry [#entryData.title#] is inactive, we highly recommed NOT installing it or contact the author about it' );
				}
				
				entryData.versions.sort( function( a, b ) { return semanticVersion.compare( b.version, a.version ) } );
				print.line();
				print.blackOnWhite( ' #entryData.title# ' )
					.boldText( '   ( #entryData.user.fname# #entryData.user.lname#, #entryData.user.email# )' )
					.boldGreenLine( '   #repeatString( '*', val( entryData.avgRating ) )#' );
				print.line()
					.yellowLine( #formatterUtil.HTML2ANSI( entryData.description )# )
					.line()
					.line( 'Type: #entryData.typeName#' )
					.line( 'Slug: "#entryData.slug#"' )
					.line( 'Summary: #entryData.summary#' )
					.line( 'Versions: #entryData.versions.map( function( i ){ return ' ' & i.version; } ).toList()#' )
					.line( 'Created On: #dateFormat( entryData.createdDate )#' )
					.line( 'Updated On: #dateFormat( entryData.updatedDate )#' )
					.line( 'ForgeBox Views: #entryData.hits#' )
					.line( 'Downloads: #entryData.downloads#' )
					.line( 'Installs: #entryData.installs#' )
					.line( 'Home URL: #entryData.homeURL#' )
					.line( 'Source URL: #entryData.sourceURL#' )
					.line();
				
			// List of entries
			} else {
				// Get the entries
				var entries = forgebox.getEntries( orderBy, maxRows, startRow, typeLookup );
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description
				
				print.line();
				var activeCount = 0;
				for( var entry in entries.results ) {
					if( val( entry.isactive ) ) {
						activeCount++;
						print.blackOnWhite( ' #entry.title# ' ); 
							print.boldText( '   ( #entry.user.fname# #entry.user.lname# )' );
							print.boldGreenLine( '   #repeatString( '*', val( entry.avgRating ) )#' );
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

	// Auto-complete 
	function lookupType( type ) {
		var typeLookup = '';
		
		// See if they entered a type name or slug
		for( var thistype in forgebox.getCachedTypes() ) {
			if( thisType.typeName == type || thisType.typeSlug == type ) {
				typeLookup = thisType.typeSlug;
				break;
			}
		}
		
		// This will be empty if not found
		return typeLookup;
		
	}

	// Auto-complete list of types
	function typeComplete( result = [] ) {
			
		// Loop over types and append all active ForgeBox entries
		for( var thistype in forgebox.getCachedTypes() ) {
			arguments.result.append( thisType.typeSlug );
		}
		
		return arguments.result;
	}

	// Auto-complete list of orderBys (can also include types and slugs)
	function orderByComplete() {
		var result = [ 'popular', 'new', 'recent', 'installs' ];
			
		// Add types
		result = typeComplete( result );
		
		// For now, I'm not going to add slugs since it will always be too many to display without prompting the user
		
		return result;
	}

} 
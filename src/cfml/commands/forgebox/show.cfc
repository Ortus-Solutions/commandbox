/**
 * This command will allow you to search for ForgeBox entires.  You can sort entires by most popular, recently updated, and newest.  
 * You can also filter for specific entry types such as cachebox, interceptors, modules, logbox, etc.
 * There are parameters to paginate results or you can pipe the output of this command into the "more" command like so:
 * -
 * forgebox show popular | more
 * -
 * Pro Tip: The first parameter will also accept a type or a slug to allow for convenient, short commands like:
 * -
 * forgebox show plugins
 * forgebox show i18n 
 **/
component extends="commandbox.system.BaseCommand" aliases="show" excludeFromHelp=false {
	
	property name="forgeBox" inject="ForgeBox";
	
	function init() {		
		return super.init( argumentCollection = arguments );
	}
	
	function onDIComplete() {
		variables.forgeboxOrders =  forgebox.ORDER;
	}

	// Lazy ForgeBox types.
	function getForgeboxTypes() {
		
		// Get and cache a list of valid ForgeBox types
		if( !structKeyExists( variables, 'forgeboxTypes' ) ) {
			variables.forgeboxTypes = forgebox.getTypes();			
		}
		return variables.forgeboxTypes;
	}
	
	/**
	* @orderBy.hint How to order results. Possible values are popular, new, and recent 
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
				slug ) {
		
		print.yellowLine( "Contacting ForgeBox, please wait..." ).toConsole();
				
		// Default parameters
		type = type ?: '';
		startRow = startRow ?: 1;
		maxRows = maxRows ?: 0;
		slug = slug ?: '';
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
							error( 'Parameter [#orderBy#] isn''t a valid orderBy, type, or slug.  Valid orderBys are [#lcase( listChangeDelims( forgeboxOrders.keyList(), ', ' ) )#] See possible types with "forgebox types".' );
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
		if( hasError() ){
			return;
		}
		
		try {
			
			// We're displaying a single entry	
			if( len( slug ) ) {
	
				// We might have gotten this above
				var entryData = entryData ?: forgebox.getEntry( slug );
				
				// entrylink,createdate,lname,isactive,installinstructions,typename,version,hits,coldboxversion,sourceurl,slug,homeurl,typeslug,
				// downloads,entryid,fname,changelog,updatedate,downloadurl,title,entryrating,summary,username,description,email
								
				if( !val( entryData.isActive ) ) {
					error( 'The ForgeBox entry [#entryData.title#] is inactive.' );
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
				
				print.yellowLine( #formatterUtil.HTML2ANSI( entryData.description )# );
				
				
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

	private function lookupType( type ) {
		var typeLookup = '';
		
		// See if they entered a type name or slug
		for( var thistype in getForgeboxTypes() ) {
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
		for( var thistype in getForgeboxTypes() ) {
			arguments.result.append( thisType.typeSlug );
		}
		
		return arguments.result;
	}

	// Auto-complete list of orderBys (can also include types and slugs)
	function orderByComplete() {
		var result = [ 'popular','new','recent' ];
			
		// Add types
		result = typeComplete( result );
		
		// For now, I'm not going to add slugs since it will always be too many to display without prompting the user
		
		return result;
	}

} 
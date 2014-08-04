/**
 * Shows all of the valid forgebox types you can use when filtering records using the "forgebox show" command.
 * .
 * {code}
 * forgebox types
 * {code}
 * .
 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	property name="forgeBox" inject="ForgeBox";
	
	function init() {
		return super.init( argumentCollection = arguments );
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
	 * 
	 **/
	function run(  ) {
		
		// typetotal,typename,typeid,typeslug
		print.line()
			.blackOnWhiteLine( 'Name (slug)' )
			.line();

		for( var type in getForgeBoxTypes() ) {
			print.boldText( type.typeName )
				.line( '  (#type.typeSlug#)' );
				
		}
		
		
	}

}
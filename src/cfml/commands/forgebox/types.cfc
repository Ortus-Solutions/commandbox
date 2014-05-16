/**
 * This command shows you all of the valid forgebox types you can use when filtering records using the "forgebox show" command.
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	
	function init() {
		
		// Create our ForgeBox helper
		variables.forgebox = new commandbox.system.util.ForgeBox();
		// Get and cache a list of valid ForgeBox types
		variables.forgeboxTypes = forgebox.getTypes();
		
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
		
		print.line();
		print.blackOnWhiteLine( 'Name (slug)' );
		print.line();
		for( var type in forgeboxTypes ) {
			print.boldText( type.typeName );
			print.line( '  (#type.typeSlug#)' );
				
		}
		
		
	}

}
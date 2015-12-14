/**
 * Shows all of the valid forgebox types you can use when filtering records using the "forgebox show" command.
 * .
 * {code:bash}
 * forgebox types
 * {code}
 * .
 
 **/
component {
	
	// DI
	property name="forgeBox" inject="ForgeBox";
	
	/**
	* Constructor
	*/
	function init(){
		super.init();
		return this;
	}

	/**
	* Run Command
	*/
	function run(  ) {
		
		// typetotal,typename,typeid,typeslug
		print.line()
			.line( "Here is a listing of the available types in ForgeBox" )
			.line()
			.blackOnWhiteLine( 'Name (slug)' );

		for( var type in forgeBox.getCachedTypes() ) {
			print.boldText( type.typeName )
				.line( '  (#type.typeSlug#)' );
				
		}
		
	}

}
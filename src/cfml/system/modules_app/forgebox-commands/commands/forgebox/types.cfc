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
	* Run Command
	*/
	function run() {
		var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );

		// typetotal,typename,typeid,typeslug
		print.line()
			.line( "Here is a listing of the available types in ForgeBox" )
			.line()
			.blackOnWhiteLine( 'Name(Number of Packages) (slug)' );

		for( var type in forgeBox.getCachedTypes( APIToken=APIToken ) ) {
			print.boldText( type.typeName & "(#type.numberOfActiveEntries#)" )
				.line( '  (#type.typeSlug#)' );
		}

	}

}
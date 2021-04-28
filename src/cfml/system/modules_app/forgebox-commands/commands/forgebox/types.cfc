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
	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";

	/**
	* Run Command
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	*/
	function run( string endpointName ) {
		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		try {
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}

		var forgebox = oEndpoint.getForgebox();
		var APIToken = oEndpoint.getAPIToken();

		// typetotal,typename,typeid,typeslug
		print.line()
			.line( "Here is a listing of the available types in ForgeBox" )
			.line()
			.blackOnWhiteLine( 'Name(Number of Packages) (slug)' );

		try {
			for( var type in forgeBox.getCachedTypes( APIToken=APIToken ) ) {
				print.boldText( type.typeName & "(#type.numberOfActiveEntries#)" )
					.line( '  (#type.typeSlug#)' );
			}
		} catch( forgebox var e ) {
			error( e.message, e.detail ?: '' );
		}

	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}

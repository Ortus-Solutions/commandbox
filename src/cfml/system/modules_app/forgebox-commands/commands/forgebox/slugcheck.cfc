/**
 * Verifies a slug against ForgeBox.
 * .
 * {code:bash}
 * forgebox slugcheck MyApp
 * {code}
 * .

 **/
component {

	// DI
	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";

	/**
	* @slug.hint The slug to verify in ForgeBox
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	*/
	function run( required slug, string endpointName ) {

		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		try {
			var oEndpoint = endpointService.getEndpoint( endpointName );
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}

		var forgebox = oEndpoint.getForgebox();
		var APIToken = oEndpoint.getAPIToken();

		if( !len( arguments.slug ) ) {
			return error( "Slug cannot be an empty string" );
		}

		try {
			var exists = forgebox.isSlugAvailable( arguments.slug, APIToken );
		} catch( forgebox var e ) {
			error( e.message, e.detail ?: '' );
		}

		if( exists ){
			print.greenBoldLine( "The slug '#arguments.slug#' does not exist in ForgeBox and can be used!" );
		} else {
			print.redBoldLine( "The slug '#arguments.slug#' already exists in ForgeBox!" );
		}

	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}

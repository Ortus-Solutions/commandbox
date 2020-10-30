/**
 * Removes a ForgeBox-based endpoint registration including any stored API Tokens
 * .
 * {code:bash}
 * forgebox endpoint remove myEndpoint
 * {code}
 **/
component {
	property name="configService" inject="configService";
	
	/**
	* @endpointName The name of the ForgeBox-based endpoint to remove
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run( required string endpointName ){
			
		if( !configService.settingExists( 'endpoints.forgebox-#endpointName#' ) ) {
			error( 'Endpoint [#endpointName#] does not exists.' );
		}
		
		var defaultForgeBoxEndpoint = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
		if( defaultForgeBoxEndpoint == endpointName ) {
			print.yellowLine( 'You are removing your default endpoint.  Removing default setting as well.' );
			configService.removeSetting( 'endpoints.defaultForgeBoxEndpoint' );
			
		}
		
		configService.removeSetting( 'endpoints.forgebox-#endpointName#' );
		
		print.greenLine( 'ForgeBox endpoint [#endpointName#] removed!' );
	}
	
	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}

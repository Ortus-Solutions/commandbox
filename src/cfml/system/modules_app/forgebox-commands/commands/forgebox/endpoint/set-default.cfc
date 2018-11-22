/**
 * Sets the default ForgeBox endpoint to use when running any forgebox command such as "forgebox search"
 * .
 * {code:bash}
 * forgebox endpoint set-default myEndpoint
 * {code}
 **/
component {
	property name="configService" inject="configService";
	
	/**
	* @endpointName The name of the ForgeBox-based endpoint to set as the default
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run( required string endpointName ){
		var endpoints = configService.getSetting( 'endpoints', {} );
		
		if( endpointName != 'forgebox' && !endpoints.keyArray().findNoCase( 'forgebox-#endpointName#' ) ) {
			error( 'Endpoint [#endpointName#] does not exist, or isn''t a ForgeBox-based endpoint.' );
		}
		
		configService.setSetting( 'endpoints.defaultForgeBoxEndpoint', endpointName );
		
		print.greenLine( 'Default ForgeBox endpoint set to [#endpointName#]' );
	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}

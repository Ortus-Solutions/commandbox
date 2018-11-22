/**
 * Registers a new ForgeBox-based endpoint
 * .
 * {code:bash}
 * forgebox endpoint register myEndpoint "http://private.forgebox.io/api/v1"
 * {code}
 **/
component {
	property name="configService" inject="configService";
	
	/**
	* @endpointName The name of the ForgeBox-based endpoint to set as the default
	* @APIURL The full HTTP address of the ForgeBox API endpoint
	**/
	function run(
		required string endpointName,
		required string APIURL ){
			
		if( configService.settingExists( 'endpoints.forgebox-#endpointName#' ) ) {
			error( 'Endpoint [#endpointName#] already exists. Please remove it first with "forgebox endpoint remove #endpointName#"' );
		} 
		
		configService.setSetting( 'endpoints.forgebox-#endpointName#', '{}' );
		configService.setSetting( 'endpoints.forgebox-#endpointName#.APIURL', APIURL );
		
		print.greenLine( 'New ForgeBox endpoint [#endpointName#] registered!' );
	}
	
}

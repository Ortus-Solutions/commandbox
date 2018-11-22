/**
 * Registers a new ForgeBox-based endpoint.
 * 
 * {code:bash}
 * forgebox endpoint register myEndpoint "https://private.forgebox.io/api/v1"
 * {code}
 * 
 * You can also use this command to update an existing endpoint URL with the --force flag.  Existing tokens will remain
 * 
 * {code:bash}
 * forgebox endpoint register myEndpoint "https://forge.intranet.local/api/v1" --force
 * {code}
 * 
 **/
component {
	property name="configService" inject="configService";
	
	/**
	* @endpointName The name of the ForgeBox-based endpoint to set as the default
	* @APIURL The full HTTP address of the ForgeBox API endpoint
	**/
	function run(
		required string endpointName,
		required string APIURL,
		boolean force=false ){
		
		if( configService.settingExists( 'endpoints.forgebox-#endpointName#' ) && !force ) {
			error( 'Endpoint [#endpointName#] already exists. Please remove it first with "forgebox endpoint remove #endpointName#"', 'Use the --force flag to skip this check.' );
		} 
		
		if( !isValid( 'URL', APIURL ) ) {
			error( 'The API URL [#APIURL#] is not a valid URL.' );
		}

		var endpointExists = configService.settingExists( 'endpoints.forgebox-#endpointName#' );

		if( !endpointExists ) {
			configService.setSetting( 'endpoints.forgebox-#endpointName#', '{}' );
		}
		configService.setSetting( 'endpoints.forgebox-#endpointName#.APIURL', APIURL );
		
		if( endpointExists ) {
			print
				.line()
				.greenLine( 'Existing ForgeBox endpoint [#endpointName#] updated!' );
		} else {
			print
				.line()
				.greenLine( 'Hot Dog-- New ForgeBox endpoint [#endpointName#] registered!' )
				.greenText( 'Log into your new endpoint with ' ).greenBoldLine( 'forgebox login endpointName=#endpointName#' );
		}
		
		print
			.line()
			.yellow( 'Please sit tight while the shell reloads...' );
		
		shell.reload( false );
	}
	
}

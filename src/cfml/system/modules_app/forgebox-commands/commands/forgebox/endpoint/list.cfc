/**
 * Lists the registered ForgeBox endpoints
 * .
 * {code:bash}
 * forgebox endpoint list
 * {code}
 **/
component {
	property name="configService" inject="configService";

	/**
	**/
	function run(){

		print.line();

		var defaultForgeBoxEndpoint = configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );
		var endpoints = duplicate( configService.getSetting( 'endpoints', {} ) );

		// Ensure the default ForgeBox endpoint is present
		endpoints[ 'forgebox' ] = endpoints.forgebox ?: {};
		endpoints.forgebox.APIURL = endpoints.forgebox.APIURL ?: 'https://www.forgebox.io/api/v1/';

		endpoints
			.filter( function( endpointName ) {
				return (endpointName.lcase().startsWith( 'forgebox-' ) || endpointName == 'forgebox' );
			} )
			.each( function( endpointName, endpointData ) {
				endpointName = endpointName.replaceNoCase( 'forgebox-', '' );
				if( isStruct( endpointData ) ) {
					print.boldCyan( 'Endpoint: #endpointName#' );
					if( defaultForgeBoxEndpoint == endpointName ) {
						print.boldRedLine( ' (Default)' );
					} else {
						print.line();
					}
					print.indentedLine( 'API URL: #( endpointData.APIURL ?: '' )#' );

					var APIToken = endpointData.APIToken ?: '';
					var tokens = endpointData.tokens ?: {};
					if( APIToken.len() ) {
						tokens.each( function( username, token ) {
							if( token == APIToken ) {
								print.indentedLine( 'Authenticated As: #username#' );
							}
						} );
					}

					print.line();
				}
			} );

	}

}

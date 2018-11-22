/**
 * Publishes a package with the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint publish" command.
 * .
 * {code:bash}
 * forgebox publish
 * {code}
 **/
component aliases="publish" {

	property name="configService" inject="configService";
	property name="endpointService" inject="endpointService";

	/**
	* @directory The directory to publish
	* @force     Force the publish
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run(
		string directory='',
		boolean force = false,
		string endpointName
	){
		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		try {		
			var APIToken = endpointService.getEndpoint( endpointName ).getAPIToken();
		} catch( EndpointNotFound var e ) {
			error( e.message, e.detail ?: '' );
		}

		if( !APIToken.len() ) {
			print.yellowLine( 'Please log into Forgebox to continue' );
			command( 'forgebox login' ).run();
		}

		// Default the endpointName
		arguments.endpointName = endpointName;

		// Defer to the generic command
		command( 'endpoint publish' )
			.params( argumentCollection=arguments )
			.run();

	}
	
	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}

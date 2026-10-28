/**
 *  Unpublishes a package from the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint unpublish" command.
 * .
 * {code:bash}
 * forgebox unpublish
 * {code}
 **/
component aliases="unpublish" {
	property name="configService" inject="configService";

	/**
	* @version The version to publish
	* @directory The directory to publish
	* @force Skip the prompt
	* @endpointName  Name of custom forgebox endpoint to use
	* @endpointName.optionsUDF endpointNameComplete
	**/
	function run(
		string version='',
		string directory='',
		boolean force=false,
		string endpointName
	){

		endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

		// Defer to the generic command
		command( 'endpoint unpublish' )
			.params( argumentCollection=arguments )
			.run();

	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}

/**
 * Publishes a package with the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint publish" command.
 * .
 * {code:bash}
 * forgebox publish
 * {code}
 **/
component aliases="publish" {

	property name="configService" inject="configService";

	/**
	* @directory The directory to publish
	**/
	function run(
		string directory=''
	){

		var APIToken = configService.getSetting( 'endpoints.forgebox.APIToken', '' );

		if( !APIToken.len() ) {
			print.yellowLine( 'Please log into Forgebox to continue' );
			command( 'forgebox login' ).run();
		}

		// Default the endpointName
		arguments.endpointName = 'forgebox';

		// Defer to the generic command
		command( 'endpoint publish' )
			.params( argumentCollection=arguments )
			.run();

	}

}
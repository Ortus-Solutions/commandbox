/**
 * Authenticates a user with the ForgeBox endpoint.  This command is a passthrough for the generic "endpoint login" command.
 * .
 * {code:bash}
 * forgebox login
 * {code}
 **/
component {

	/**
	* @username.hint Username for this user
	* @password.hint Password for this user
	**/
	function run(
		string username='',
		string password=''
	){

		// Default the endpointName
		arguments.endpointName = 'forgebox';

		// Ask for username if not passed
		if( !len( arguments.username ) ) {

			// Info for ForgeBox
			print.line()
				.line( "Login with your ForgeBox ID to publish and manage packages in Forgebox.io. ")
				.line( "If you don't have a ForgeBox ID, head over to https://www.forgebox.io to create one or just use the" )
				.boldRed( " forgebox register ")
				.line( "command to register a new account.")
				.line()
				.toConsole();

            arguments.username = ask( 'Enter your username: ' );
        }

   		// Ask for password if not passed
        if( !len( arguments.password ) ) {
            arguments.password = ask( 'Enter your password: ', '*' );
        }

		// Message user since there can be a couple-second delay here
		print.line()
			.yellowLine( 'Contacting ForgeBox...' )
			.toConsole();

		// Defer to the generic command
		command( 'endpoint login' )
			.params( argumentCollection=arguments )
			.run();

	}

}
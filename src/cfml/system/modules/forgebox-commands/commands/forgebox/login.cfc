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
		string username,
		string password 
	){

		// Default the endpointName
		arguments.endpointName = 'forgebox';

		// Info for ForgeBox
		print.line( "Login with your ForgeBox ID to publish and manage packages in Forgebox.io. ")
			.line( "If you don't have a ForgeBox ID, head over to https://www.forgebox.io to create one or just use the" )
			.boldRed( " forgebox register ")
			.line( "command to register a new account.")
			.line()
			.toConsole();

		// Ask for username/password if not passed
		if( !len( arguments.username ) ) {
            arguments.username = ask( 'Enter your username: ' );
        }
        if( !len( arguments.password ) ) {
            arguments.password = ask( 'Enter your password: ', '*' );            
        }

		// Defer to the generic command
		command( 'endpoint login' )
			.params( argumentCollection=arguments )
			.run();
			
	}

}
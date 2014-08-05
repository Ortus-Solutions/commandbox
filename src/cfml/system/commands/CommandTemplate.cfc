/**
 * Output information to the user.  Extra details here.
 * .
 * {code:bash}
 * commandtemplate
 * {code}
 * .
 * Here's another way to call it
 * {code:bash}
 * commandtemplate --arg2
 * {code}
 *
 **/	
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @arg1.hint The first argument
	 * @arg2.hint The second argument
	 **/
	function run( required arg1, boolean arg2=false )  {
		
		// Make path canonical and absolute
		arguments.path = fileSystemUtil.resolvePath( arguments.path );
			
		// Exit command with error
		return error( 'There was an error' );
					
		// Print text
		print.whiteOnRedText( 'foo' );
		print.greenLine( "Yes!!" );
		print.boldRedLine( "No!!" );
				
		// Confirm with user
		if( confirm( "Are you sure? [y/n]" ) ) {
			
		}
			
		// Ask user a question
		var response = ask( "What's your favorite color?");
			
	}
	
}
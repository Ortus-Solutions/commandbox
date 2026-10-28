/**
 * Prompt the user for a yes/no.  Requires an interactive terminal.
 * An exit code of 0 is returned for a true response, and an exit code of 1 is retured for a false response.
 * .
 * Output a single file
 * {code:bash}
 * confirm "do you want to update? " && update
 * {code}
 * 
 **/
component {

	/**
	 * @question Question to ask the user
	 * @defaultResponse Default what shows in the buffer
	 * @mask Set to a char like * to hide passwords, etc
 	 **/
	function run( required string question )  {
		if( confirm( question ) ) {
			setExitCode( 0 );
		} else {
			setExitCode( 1 );
		}
	}

}

/**
 * Clears a System Setting from the current environment
 * .
 * {code:bash}
 * env set foo=bar
 * env clear for
 * {code}
 *
 * No error is thrown if the var doesn't exist.
  **/
component  {

	/**
	* @name The env var to clear
	*/
	function run( required string name )  {
		var env = systemSettings.getCurrentEnvironment( true );
		env.delete( name );
		print.line( '#name# cleared' );
	}

}

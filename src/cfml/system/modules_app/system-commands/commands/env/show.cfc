/**
 * Shows a System Setting from the current environment
 * .
 * {code:bash}
 * env set foo=bar
 * env show foo
 * {code}
 * .
 * If you don't pass a name, you will get a JSON representation of the entire environment struct.
 * .
 * {code:bash}
 * env show
 * {code}
 *
 * Note that a command calling another command creates nested environments that inherit.  A given 
 * system setting not present in the current environment may still reseolve because it is found in a 
 * parent environment context.
  **/
component  {

	/**
	* @name The env var to show
	* @defaultValue Value to return if this env var doen't exist.
	*/
	function run( string name='', defaultValue='' )  {
		if( name.len() ) {
			print.line( systemSettings.getSystemSetting( name, defaultValue ) );	
		} else {
			print.line( systemSettings.getCurrentEnvironment( true ) );			
		}
	}

}

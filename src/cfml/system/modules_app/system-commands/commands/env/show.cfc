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
 * This command does not include Java system properties or OS environment variables even though
 * they are included in the lookup order for System Setting resolution.
  **/
component  {

	/**
	* @name The env var to show
	* @defaultValue Value to return if this env var doesn't exist.
	*/
	function run( string name='', defaultValue='' )  {
		if( name.len() ) {
			print.text( systemSettings.getSystemSetting( name, defaultValue ) );
		} else {
			print.text( systemSettings.getAllEnvironmentsFlattened() );
		}
	}

}

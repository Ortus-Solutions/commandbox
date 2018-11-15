/**
 * Shows a System Setting from the current environment
 * .
 * {code:bash}
 * env set foo=bar
 * env show foo
 * {code}
  **/
component  {

	/**
	* @name The env var to show
	* @defaultValue Value to return if this env var doen't exist.
	*/
	function run( required string name, defaultValue='' )  {
		print.line( systemSettings.getSystemSetting( name, defaultValue ) );
	}

}

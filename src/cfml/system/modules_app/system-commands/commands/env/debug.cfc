/**
 * Debugs what env vars are loaded in what environments
 * .
 * {code:bash}
 * env debug
 * {code}
 *
 * This command does not include Java system properties or OS environment variables even though
 * they are included in the lookup order for System Setting resolution.
*/
component  {

	/**
	*
	*/
	function run()  {
		print.text( systemSettings.getAllEnvironments() );
	}

}

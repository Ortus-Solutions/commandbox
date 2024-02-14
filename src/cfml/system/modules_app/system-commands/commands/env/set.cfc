/**
 * Sets a System Setting in the current environment
 * .
 * {code:bash}
 * set foo=bar
 * {code}
  **/
component aliases="set" {

	/**
	*
	*/
	function run()  {
		for( var arg in arguments ) {
			systemSettings.setSystemSetting( arg, arguments[ arg ], true );
			print.text( '#arg#=#arguments[ arg ]#' );
		}
	}

}

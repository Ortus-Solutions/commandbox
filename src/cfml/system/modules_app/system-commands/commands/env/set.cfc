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
			SystemSettings.setSystemSetting( arg, arguments[ arg ], true );
			print.line( '#arg#=#arguments[ arg ]#' );	
		}
	}

}

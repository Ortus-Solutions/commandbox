/**
 * Returns a passing (0) or failing (1) exit code if parameters do not match.  Command outputs nothing.
 * Comparison is case insensitive.
 * .
 * {code:bash}
 * assertNotEqual `package show name` "My Package" && package set name="My Package"
 * assertNotEqual ${ENVIRONMENT} development && install --production
 * {code}
 *
**/
component {

	/**
	* @value1 A value to be compared to value2
	* @value2 A value to be compared to value1
	**/
	function run( required string value1, required string value2 )  {

		if( value1 == value2 ) {
			setExitCode( 1 );
		}

	}

}

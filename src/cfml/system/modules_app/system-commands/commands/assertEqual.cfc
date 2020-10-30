/**
 * Returns a passing (0) or failing (1) exit code whether both parameters match.  Command outputs nothing.
 * Comparison is case insensitive.
 * .
 * {code:bash}
 * assertEqual `package show name` "My Package" || package set name="My Package"
 * assertEqual ${ENVIRONMENT} production && install --production
 * {code}
 *
 * Values are not trimmed, but you can trim them if you want
 * .
 * {code:bash}
 * assertEqual "brad" `ECHO " BRAD " | #trim` && ECHO HI
 * {code}
 *
**/
component {

	/**
	* @value1 A value to be compared to value2
	* @value2 A value to be compared to value1
	**/
	function run( required string value1, required string value2 )  {
		
		if( value1 != value2 ) {
			setExitCode( 1 );
		}
		
	}

}

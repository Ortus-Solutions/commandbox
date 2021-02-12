/**
 * Returns a passing (0) or failing (1) exit code whether truthy parameter passed.  Command outputs nothing.
 * Truthy values are "yes", "true" and positive integers.
 * All other values are considered falsy
 * .
 * {code:bash}
 * assertTrue `package show private` && run-script foo
 * assertTrue ${ENABLE_DOOM} && run-doom
 * assertTrue `#fileExists foo.txt` && echo "it's there!"
 * {code}
**/
component {

	/**
	* @predicate A value that is truthy or falsy.
	**/
	function run( required string predicate )  {

		if( isBoolean( predicate ) && predicate ) {
			// Nothing
		} else {
			setExitCode( 1 );
		}

	}

}

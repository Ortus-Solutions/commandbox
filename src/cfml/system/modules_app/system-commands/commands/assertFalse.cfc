/**
 * Returns a passing (0) or failing (1) exit code if a falsey parameter passed.  Command outputs nothing.
 * Falsey values are arenything OTHER than "yes", "true" and positive integers.
 * .
 * {code:bash}
 * assertFalse `package show private` && run-script foo
 * assertFalse ${GOOD_THINGS} && run-doom
 * assertFalse `#fileExists foo.txt` && echo "it's not there!"
 * {code}
**/
component {

	/**
	* @predicate A value that is truthy or falsy.
	**/
	function run( required string predicate )  {

		if( isBoolean( predicate ) && predicate ) {
			setExitCode( 1 );
		}

	}

}

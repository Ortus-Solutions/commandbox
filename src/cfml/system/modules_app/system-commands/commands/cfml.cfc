/**
 * I am a shortcut to run single CFML functions via the REPL. This example runs the now() function.
 * It is the equivalent to "repl now()".
 * .
 * {code:bash}
 * cfml now
 * {code}
 *
 * As a handy shortcut, you can invoke the "cfml" command by simply typing the name of the CFML
 * function, preceded by a # sign.
 *
 * {code:bash}
 * #now
 * {code}
 *
 * When you pass parameters into this command, they will be passed directly along to the CFML function.
 *
 * {code:bash}
 * #hash mypass
 * #reverse abc
 * {code}
 *
 * This really gets useful when you start piping input into CFML functions.  Like other CFML commands, piped
 * input will get passed as the first parameter to the function.  This allows you to chain CFML functions
 * from the command line like so.  (Outputs "OOF")
 *
 * {code:bash}
 * #listGetAt www.foo.com 2 . | #ucase | #reverse
 * {code}
 *
 * Since this command defers to the REPL for execution, complex return values such as arrays or structs will be
 * serialized as JSON on output.  As a convenience, if the first input to an array or struct function looks like
 * JSON, it will be passed directly as a literal instead of a string.
 * .
 * The first example averages an array.  The second outputs an array of dependency names in your app by manipulating
 * the JSON object  that comes back from the "package list" command.
 *
 * {code:bash}
 * #arrayAvg [1,2,3]
 * package list --JSON | #structFind dependencies | #structKeyArray
 * {code}
 *
 * You must use positional parameters if you are piping data to a CFML function, but you do have the option to use
 * named parameters otherwise.  Those names will be passed along directly to the CFML function, so use the CF docs to make sure
 * you're using the correct parameter name.
 *
 * {code:bash}
 * #directoryList path=D:\\ listInfo=name
 * {code}
 *
 **/
component{

	/**
	* @name.hint The name of the CFML function to run
	**/
	function run(
		required string name
		boolean debug
	){
		var functionText = arguments.name & '( ';

		// Additional param go into the function
		if( arrayLen( arguments ) > 1 ) {

			// Positional params
			if( isNumeric( listGetAt( structKeyList( arguments ), 2 ) ) ) {

				var i = 1;
				while( ++i <= arrayLen( arguments ) ) {

					functionText &= ( i>2 ? ', ' : '' );
					arguments[ i ] = print.unansi( arguments[ i ] );

					// If this is a struct or array function, we have at least one param, and it's JSON, just pass it in as complex data.
					if( ( left( arguments.name, 5 ) == 'array' || left( arguments.name, 6 ) == 'struct' || arguments.name == 'isArray'  || arguments.name == 'isStruct' )
					    && i==2 && isJSON( arguments[ i ] ) ) {
						functionText &= '#convertJSONEscapesToCFML( arguments[ i ] )#';
					} else {
						functionText &= '"#escapeArg( arguments[ i ] )#"';
					}

				} // end param loop


			// Named params
			} else {

				var i = 0;
				for( var param in arguments ) {
					if( param=='name' ) {
						continue;
					}
					i++;

					functionText &= ( i>1 ? ', ' : '' );

					functionText &= '#param#="#escapeArg( print.unansi( arguments[ param ] ) )#"';

				} // end param loop


			}


		} // end additional params?

		functionText &= ' )';

		// Run our function via the REPL
		var result = command( "repl" )
			.params( functionText )
			.run( returnOutput=true, echo=false );

		// Print out the results
		print.text( result );

	}

	private function escapeArg( required string arg ) {
		arguments.arg = replaceNoCase( arguments.arg, '"', '""', 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '##', '####', 'all' );
		return arguments.arg;
	}

	// A complex value serialized as JSON differs from CFML struct literals in that
	// double quotes are \" instead of "".  Any escaped double quotes must be converted
	// to the CFML version to work as an object literal.
	private function convertJSONEscapesToCFML( required string arg ) {
		arguments.arg = replaceNoCase( arguments.arg, '\\', '__double_backslash_', 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\/', '/', 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\"', '""', 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '##', '####', 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\t', '	', 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\n', chr(13)&chr(10), 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\r', chr(13), 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\f', chr(12), 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '\b', chr(8), 'all' );

		// A null keyword must be preceded by a , [ : or start of string.
		// TODO: This doesn't account for the word "null" inside a quoted string.  I'd need to actually parse the string to detect that.
		arguments.arg = reReplaceNoCase( arguments.arg, '(,\s*)null', '\1nullValue()', 'all' );
		arguments.arg = reReplaceNoCase( arguments.arg, '(\[\s*)null', '\1nullValue()', 'all' );
		arguments.arg = reReplaceNoCase( arguments.arg, '(:\s*)null', '\1nullValue()', 'all' );
		arguments.arg = reReplaceNoCase( arguments.arg, '^null', 'nullValue()', 'all' );

		// This doesn't work-- I'd need to do it in a loop and replace each one individually.  Meh...
		// arguments.arg = reReplaceNoCase( arguments.arg, '\\u([0-9a-f]{4})', chr( inputBaseN( '\1', 16 ) ), 'all' );
		arguments.arg = replaceNoCase( arguments.arg, '__double_backslash_', '\', 'all' );
		return arguments.arg;
	}

}

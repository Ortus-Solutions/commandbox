/**
 * Replace text tokens in one or more files.  Token matches are case insensitive.
 * .
 * {code:bash}
 * tokenReplace path=/path/to/file.txt token="@@version@@" replacement=`package version`
 * tokenReplace path=/tests/*.cfc token="@@version@@" replacement=`package version`
 * {code}
 * .
 * Use the "verbose" param to see all the files affected
 * .
 * {code:bash}
 * tokenReplace path=file.txt token="foo" replacement="bar"
 * {code}
 *
 **/
component {

	/**
	 * @path file(s) to replace tokens in. Globbing patters allowed such as *.txt
	 * @token The token to search for
	 * @replacement The replacement text to use
	 * @verbose Output file names that have been modified
	 **/
	function run(
		required Globber path,
		required String token,
		required String replacement,
		boolean verbose=false )  {

		path.apply( function( thisPath ) {

			// It's a file
			if( fileExists( thisPath ) ){
				if( verbose ) {
					print.greenLine( thisPath );
				}
				var fileContents = fileRead( thisPath );
				if( fileContents.findNoCase( token ) ) {
					fileWrite( thisPath, fileContents.replaceNoCase( token, replacement, 'all' ) );
				}
			}

		} );
	}

}

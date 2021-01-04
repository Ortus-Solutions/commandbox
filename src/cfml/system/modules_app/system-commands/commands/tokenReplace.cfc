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

	BOMInputStream = createObject( 'java', 'org.apache.commons.io.input.BOMInputStream' );
	FileInputStream = createObject( 'java', 'java.io.FileInputStream' );
	// Assuming UTF-8 BOM
	UTF8_BOM = javacast( 'byte[]', [ -17, -69, -65 ] );

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
				var fileContents = fileRead( thisPath, "UTF-8" );
				if( fileContents.findNoCase( token ) ) {
					var hasBOM = hasBOM( thispath )
					if( verbose ) {
						print.greenLine( thisPath & ( hasBOM ? ' (with BOM)' : '' ) );
					}
					var newContent = fileContents.replaceNoCase( token, replacement, 'all' );
					if( hasBOM ) {
						newContent = UTF8_BOM & newContent;
					}
					fileWrite( thisPath, newContent, "UTF-8" );
				}
			}

		} );
	}
	
	private boolean function hasBOM( thispath ) {
		try {
			var thisFile = BOMInputStream.init( FileInputStream.init( thispath ), true );
			return thisFile.hasBOM();
		} finally {
			thisFile.close();
		}
	}

}

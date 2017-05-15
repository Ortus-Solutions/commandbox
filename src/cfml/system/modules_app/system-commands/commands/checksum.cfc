/**
 * Generate checksum for a file or a directory via a globbiner pattern. 
 * Default is MD5, but SHA-1, SHA-256, and SHA-512 can also be used.
 * .
 * {code:bash}
 * checksum path=file.txt
 * checksum path=*.zip
 * checksum path=build.zip SHA-256
 * {code}
 *
 **/	
component {

	variables.algorithms = 'MD5,SHA1,SHA-1,SHA-256,SHA-512';

	/**
	 * @path Path of file or globbing pattern to create checksum of
	 * @algorithm Hashing algorithm to use
	 * @algorithm.optionsUDF algorithmComplete
	 **/
	function run(
		required Globber path,
		String algorithm='MD5' )  {
			
			if( !variables.algorithms.listFindNoCase( algorithm ) ) {
				error( 'The hashing algorithm [#algorithm#] is not supported' );
			}
						
			if( !path.count() ) {
				error( "File or globbing pattern doesn't exist. I can't hash thin air! [#path.getPattern()#]" );
			}
			
			// If matching single file, just hash that file
			if( path.count() == 1 ) {
				print.text( hash( fileReadBinary( path.asArray().matches()[ 1 ] ), algorithm ) );
			// If matching directory, hash the query
			} else {
				print.text( hash( serializeJSON( path.asQuery().matches() ), algorithm ) );
			}
			
	}
	
	function algorithmComplete() {
		return variables.algorithms.listToArray();
	}
	
}
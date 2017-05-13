/**
 * Generate checksum for a file. Default is MD5, but SHA-1, SHA-256, and SHA-512 can also be used.
 * .
 * {code:bash}
 * checksum path=file.txt
 * checksum path=build.zip SHA-256
 * {code}
 *
 **/	
component {

	variables.algorithms = 'MD5,SHA1,SHA-1,SHA-256,SHA-512';

	/**
	 * @file file to create checksum of
	 * @algorithm Hashing algorithm to use
	 * @algorithm.optionsUDF algorithmComplete
	 **/
	function run(
		required String file,
		String algorithm='MD5' )  {
			
			if( !variables.algorithms.listFindNoCase( arguments.algorithm ) ) {
				error( 'The hashing algorithm [#arguments.algorithm#] is not supported' );
			}
			
			arguments.file = filesystemUtil.resolvePath( arguments.file );
			
			if( !fileExists( arguments.file ) ) {
				error( "File doesn't exist. I can't hash thin air! [#arguments.file#]" );
			}
			
			print.text( hash( fileReadBinary( arguments.file ), arguments.algorithm ) );
			
	}
	
	function algorithmComplete() {
		return variables.algorithms.listToArray();
	}
	
}
/**
 * Generate checksum for a file or a directory via a globbing pattern.
 * Default is MD5, but SHA-1, SHA-256, and SHA-512 can also be used.
 * .
 * {code:bash}
 * checksum file.txt
 * checksum build.zip SHA-256
 * {code}
 *
 * Create a checksum for more than one file in a directory with a file globbing pattern
 * .
 * {code:bash}
 * checksum path=*.zip
 * {code}
 *
 * Write checksum(s) to a file named after the original file plus a new extension.
 * This will create a file called "myFile.zip.md5".
 * .
 * {code:bash}
 * checksum myFile.zip md5 --write
 * {code}
 *
 * Control the file extension like so.  (--write is optional when supplying an extension)
 * This will create a file called "myFile.zip.hash".
 * .
 * {code:bash}
 * checksum path=myFile.zip extension=hash --write
 * {code}
 *
 * Control the format of the hash with the "format" parameter.
 *
 * {code:bash}
 *   - "checksum" (default) -- just the hash
 *   - "md5sum" -- The format of GNU textutils md5sum
 *   - "sfv" -- The format of BSDs md5 command
 * {code}
 *
 * Verify a file against an existing hash. Error will be thrown if checksums are different
 * .
 * {code:bash}
 * checksum path=myFile.zip verify=2A95F32028087699CCBEB09AFDA0348C
 * {code}
 *
 **/
component {

	variables.algorithms = 'md5,sha1,sha-1,sha-256,sha-512';
	variables.formats = 'checksum,md5sum,sfv';

	/**
	 * @path Path of file or globbing pattern to create checksum of
	 * @algorithm Hashing algorithm to use
	 * @algorithm.optionsUDF algorithmComplete
	 * @extension File extension to write. Using this sets write to true.
	 * @extension.optionsUDF algorithmComplete
	 * @format Format to write hash in. checksum, md5sum, or sfv
	 * @format.optionsUDF formatComplete
	 * @verify A hash to verify to a file. Error will be thrown if checksums don't match.
	 * @write Set true to write checksum to a file instead of outputting to console
	 **/
	function run(
		required Globber path,
		String algorithm='md5',
		String extension,
		String format='checksum',
		String verify='',
		Boolean write=false
		 )  {
		 	// Setting extension, defaults write to on.
		 	if( !isNull( extension ) ) {
		 		write = true;
		 	}
		 	// Default extension is algorithm name
		 	extension = extension ?: algorithm;

			// validate format
			if( !variables.formats.listFindNoCase( format ) ) {
				error( 'The checksum format [#format#] is not supported' );
			}

			// Validate algorithm
			if( !variables.algorithms.listFindNoCase( algorithm ) ) {
				error( 'The hashing algorithm [#algorithm#] is not supported' );
			}

			// If file or glog doesn't exist, error.
			if( !path.count() ) {
				error( "File or globbing pattern doesn't exist. I can't hash thin air! [#path.getPattern()#]" );
			}

			// If verifying a hash, only one file can be matched
			if( verify.len() && path.count() > 1 ) {
				error( 'You can only verify a single hash/file at a time.' );
			}

			// Loop over matched globbing patterns
			path.apply( function( thisPath ){
				var thisHash = hash( fileReadBinary( thisPath ), algorithm );

				// Verifying incoming hash
				if( verify.len() ) {
					// Doesn't match
					if( compare( thisHash, verify ) != 0 ) {
						error( 'File checksum [#thisHash#] does not match incoming verification checksum [#verify#].' );
					// Does match
					} else {
						print.greenLine( 'Checksum matches [#thisHash#]' );
						return;
					}
				}

				// Default output format is just the checksum
				var formattedHash = thisHash;

				// Match the format of GNU textutils md5sum
				if( format == 'md5sum' ) {
					var formattedHash = thisHash & ' *' & listLast( thisPath, '/\' );
				// Match the format of BSDs md5 command
				} else if( format == 'sfv' ) {
					var formattedHash = '(' & listLast( thisPath, '/\' ) & ')' & ' = ' & thisHash;
				}

				// If writing file
				if( write ) {
					fileWrite( thisPath & '.' & extension, formattedHash );
				// If outputting
				} else {

					print
						.text( formattedHash )
						.toConsole();

					// If we're doing more than one hash, put a line break in.
					if( path.count() > 1 ) {
						print.line();
					}

				}
			} );

	}

	function algorithmComplete() {
		return variables.algorithms.listToArray();
	}

	function formatComplete() {
		return variables.formats.listToArray();
	}



}

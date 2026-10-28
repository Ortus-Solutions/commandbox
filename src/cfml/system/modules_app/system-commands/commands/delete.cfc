/**
 * Delete a file or directory from the filesystem.  Path may be absolute or relative to the current working directory.
 * .
 * {code:bash}
 * delete sample.html
 * {code}
 * .
 * Use the "force" param to suppress the confirmation dialog.
 * .
 * {code:bash}
 * delete sample.html --force
 * {code}
 * .
 * Use the "recurse" param to remove a directory which is not empty.  Trying to remove a non-empty
 * directory will throw an error.  This a safety check to make sure you know what you are getting into.
 * .
 * {code:bash}
 * delete myFolder/ --recurse
 * {code}
 **/
component aliases="rm,del" {

	/**
	 * @path.hint file or directory to delete. Globbing patters allowed such as *.txt
	 * @force.hint Force deletion without asking
	 * @recurse.hint Delete sub directories
	 **/
	function run( required Globber path, Boolean force=false, Boolean recurse=false )  {

		path.apply( function( thisPath ) {
			// It's a directory
			if( directoryExists( thisPath ) ) {

					var subMessage = recurse ? ' and all its subdirectories' : '';

					if( force || confirm( "Delete #thisPath##subMessage#? [y/n]" ) ) {

						if( directoryList( thisPath ).len() && !recurse ) {
							return error( 'Directory [#thisPath#] is not empty! Use the "recurse" parameter to override' );
						}
						// Catch this to gracefully handle where the OS or another program
						// has the folder locked.
						try {
							directoryDelete( thisPath, recurse );
							print.greenLine( "Deleted #thisPath#" );
						} catch( any e ) {
							error( '#e.message# #CR#The folder is possibly locked by another program.'  );
							logger.error( '#e.message# #e.detail#' , e.stackTrace );
						}
					} else {
						print.redLine( "Cancelled!" );
					}


			// It's a file
			} else if( fileExists( thisPath ) ){

				if( force || confirm( "Delete #thisPath#? [y/n]" ) ) {

						// Catch this to gracefully handle where the OS or another program
						// has the file locked.
						try {
							fileDelete( thisPath );
							print.greenLine( "Deleted #thisPath#" );
						} catch( any e ) {
							error( '#e.message##CR#The file is possibly locked by another program.'  );
							logger.error( '#e.message# #e.detail#' , e.stackTrace );
						}
				} else {
					print.redLine( "Cancelled!" );
				}

			} else {
				return error( "File/directory does not exist: #thisPath#" );
			}

		} );
	}

}

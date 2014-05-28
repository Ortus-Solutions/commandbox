/**
 * Delete a file or directory from the filesystem
 *
 * delete sample.html
 *
 **/	
component extends="commandbox.system.BaseCommand" aliases="rm,del" excludeFromHelp=false {

	/**
	 * @file.hint file or directory to delete
	 * @force.hint force deletion
	 * @recurse.hint recursive deletion of files
	 **/
	function run( required file="", Boolean force=false, Boolean recurse=false )  {
		
		// If files does't, maybe they meant a relative file
		if( !fileExists( arguments.file ) ) {
			arguments.file = shell.pwd() & '/' & arguments.file;
		}
		
		if( !fileExists( arguments.file ) ) {
			if( directoryExists( arguments.file ) ){
				
				var isConfirmed = shell.ask( "delete #file#? and all its subdirectories? [y/n] : " );
				if( left( isConfirmed, 1 ) == "y" 
					|| ( isBoolean( isConfirmed ) && isConfirmed ) ) {
					directoryDelete( arguments.file, true );
					return "deleted #arguments.file#";
				}
				return 'Cancelled.';
			}
			shell.printError( {message="file/directory does not exist: #arguments.file#"} );
		} else {
			var isConfirmed = shell.ask("delete #arguments.file#? [y/n] : ");
			if( left( isConfirmed, 1 ) == "y" 
				|| ( isBoolean( isConfirmed ) && isConfirmed ) ) {
				fileDelete( arguments.file );
				return "deleted #arguments.file#";
			}
			return 'Cancelled.';
		}
		return "";
	}



}
/**
 * Delete a file or directory from the filesystem
 *
 * delete sample.html
 *
 **/	
component persistent="false" extends="commandbox.system.BaseCommand" aliases="rm,del" excludeFromHelp=false {

	/**
	 * @file.hint file or directory to delete
	 * @force.hint force deletion
	 * @recurse.hint recursive deletion of files
	 **/
	function run( required file="", Boolean force=false, Boolean recurse=false )  {
		
		// If files does't, maybe they meant a relative file
		if( !fileExists( file ) ) {
			file = shell.pwd() & '/' & file;
		}
		
		
		if( !fileExists( file ) ) {
			shell.printError({message="file does not exist: #file#"});
		} else {
			var isConfirmed = shell.ask("delete #file#? [y/n] : ");
			if(left(isConfirmed,1) == "y" 
				|| ( isBoolean(isConfirmed) && isConfirmed ) ) {
				fileDelete(file);
				return "deleted #file#";
			}
		}
		return "";
	}



}
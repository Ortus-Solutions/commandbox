/**
 * delete a file or directory
  **/	
component persistent="false" extends="cli.BaseCommand" aliases="rm,del" {

	/**
	 * @file.hint file or directory to delete
	 * @force.hint force deletion
	 * @recurse.hint recursive deletion of files
	 **/
	function run( required file="", Boolean force=false, Boolean recurse=false )  {
		if(!fileExists(file)) {
			shell.printError({message="file does not exist: #file#"});
		} else {
			var isConfirmed = shell.ask("delete #file#? [y/n] : ");
			if(left(isConfirmed,1) == "y" || isBoolean(isConfirmed) && isConfirmed) {
				fileDelete(file);
				return "deleted #file#";
			}
		}
		return "";
	}



}
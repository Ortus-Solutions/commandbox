/**
 * Lists the files and folders in a given directory.  Defaults to current working directory
 *
 * dir samples
 * 
 **/
component persistent="false" extends="commandbox.system.BaseCommand" aliases="ls,directory" excludeFromHelp=false {

	/**
	 * @directory.hint The directory to list the contents of
	 * @recurse.hint recursively list
	 **/
	function run( String directory="", Boolean recurse=false )  {
		// This will make each directory canonical and absolute		
		directory = fileSystemUtil.resolveDirectory( directory );
		
		for(var d in directoryList(directory,recurse)) {
			print.cyanLine( d );
		}
	}


}
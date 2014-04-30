/**
 * List directories
 * 	ex: dir /my/path
 **/
component persistent="false" extends="cli.BaseCommand" aliases="ls,directory" {

	/**
	 * @directory.hint directory
	 * @recurse.hint recursively list
	 **/
	function run( String directory="", Boolean recurse=false
	)  {
		directory = trim(directory) == "" ? shell.pwd() : directory;
		for(var d in directoryList(directory,recurse)) {
			print.cyanLine( d );
		}
	}


}
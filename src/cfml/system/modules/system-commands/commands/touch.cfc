/**
 * Create a new file according to its name if it does not exist. If it exists, modify its last updated date and time to now.
 * .
 * {code:bash}
 * touch file.txt
 * {code}
 * .
 * Use the force parameter to overwrite the contents of the file to be empty even if it exists.
 * .
 * {code:bash}
 * touch file.txt --force
 * {code}
 * 
 **/
component aliases="new" {

	/**
	 * @file.hint File to create
	 * @force.hint If forced, then file will be recreated even if it exists
 	 **/
	function run( required file, boolean force=false )  {
		
		arguments.file = fileSystemUtil.resolvePath( arguments.file );

		var oFile = createObject( "java", "java.io.File" ).init( arguments.file );
		var fileName = listLast( arguments.file, "/" );

		// if we have a force, recreate the file
		if( arguments.force and oFile.existS() ){
			oFile.delete();
		}
		
		// check for update or creation
		if( !oFile.exists() ){
			oFile.createNewFile();
			return "#fileName# created!";
		} else {
			oFile.setLastModified( now().getTime() );
			return "#fileName# last modified bit updated!";
		}

		
	}

}
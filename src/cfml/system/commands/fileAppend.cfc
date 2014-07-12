	/**
 * This command will append to a file, creating it if doesn't exists. You can pipe content into it.
 * This comand is used for redirection when you type echo "text" >> file.txt
 * .
 * fileAppend "My new line" file.txt
 * .
 * echo "My new line" | fileAppend file.txt
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=true {

	/**
	 * @contents.hint Contents to append to the file
	 * @file.hint File to append to
 	 **/
	function run( required contents='', required string file )  {
		
		arguments.file = fileSystemUtil.resolvePath( arguments.file );

		file  
		    action = "append" 
		    file = "#arguments.file#" 
		    output = "#arguments.contents#" 
		    addNewLine = "yes";
		
	}

}
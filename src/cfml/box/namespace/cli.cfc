/**
 * This is the MAIN CLI
 **/
component output="false" persistent="false" trigger="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		cr = chr(10);
		return this;
	}

	/**
	 * Display help information
	 **/
	function help(String namespace="", String command="")  {
		return shell.help(namespace,command);
	}

	/**
	 * List directories
	 * 	ex: dir /my/path
	 *  @command.aliases ls, directory
	 **/
	function dir(String directory="", Boolean recurse=false)  {
		var result = "";
		directory = trim(directory) == "" ? shell.pwd() : directory;
		for(var d in directoryList(directory,recurse)) {
			result &= shell.ansi("cyan",d) & cr;
		}
		return result;
	}

	/**
	 * Get version
	 **/
	function version()  {
		return "1.0.0";
	}


	/**
	 * Set prompt
	 **/
	function prompt(String prompt="")  {
		shell.setPrompt(prompt);
	}

	/**
	 * Clear screen
	 **/
	function clear()  {
		shell.clearScreen();
	}

	/**
	 * print working directory (current dir)
	 **/
	function pwd()  {
		return shell.pwd();
	}

	/**
	 * change directory
	 **/
	function cd(directory="")  {
		return shell.cd(directory);
	}

	/**
	 * display file contents
	 * @command.aliases type
	 **/
	function cat(file="")  {
		if(left(file,1) != "/"){
			file = shell.pwd() & "/" & file;
		}
		return fileRead(file);
	}

	/**
	 * delete a file or directory
	 * @command.aliases rm,del
	 * @file.hint file or directory to delete
	 * @force.hint force deletion
	 * @recurse.hint recursive deletion of files
	 **/
	function delete(required file="", Boolean force=false, Boolean recurse=false)  {
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

	/**
	 * executes a cfml file
	 **/
	function execute(file="")  {
		return include(file);
	}

	/**
	* Exit
	* @command.aliases quit,q,e
	*/
	function exit()  {
		shell.exit();
	}

	/**
	 * Reload CLI
	 **/
	function reload(Boolean clearScreen=true)  {
		shell.reload(clearScreen);
	}


}
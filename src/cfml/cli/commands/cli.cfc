/**
 * General CLI commands (in the default namespace)
 * You can specify the command name to use with: @command.name
 * and you can specify any aliases (not shown in command list)
 * via: @command.aliases list,of,aliases
 **/
component persistent="false" extends="cli.BaseCommand" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		cr = chr(10);
		return this;
	}

	/**
	 * List directories
	 * 	ex: dir /my/path
	 * @directory.hint directory
	 * @recurse.hint recursively list
 	 * @command.aliases ls, directory
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
	 * returns shell version
	 **/
	function version()  {
		return shell.version();
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
	 * @directory.hint directory to CD to
* 	 **/
	function cd(directory="")  {
		return shell.cd(directory);
	}

	/**
	 * display file contents
	 * @command.aliases type
	 * @file.hint file to view contents of
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
	 * @clearScreen.hint clears the screen after reload
  	 **/
	function reload(Boolean clearScreen=true)  {
		shell.reload(clearScreen);
	}


}
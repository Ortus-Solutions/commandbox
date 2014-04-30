/**
 * get help information
 **/
component extends="cli.BaseCommand" {


	function run( string command='' )  {
		var commandHandler = shell.getCommandHandler(); 
		var allCommands = commandHandler.getCommands();
		var result = shell.ansi('green','HELP #command#') & cr;
		
		// If we're getting help for a specific command
		if( len( command ) ) {
			// Resolve the string to the command
			var commandInfo = commandHandler.resolveCommand( line=command, substituteHelp=false );
			
			// We found the command!
			if( commandInfo.found ) {
				
				shell.printError({message:'No help found for #namespace# #command#'});
				
			// No clue what you're talking about (command not found)
			} else {
				
				
			}
			
		// General help
		} else {
			
		}
		
		writeDump( allCommands );abort;
		
		var result = shell.ansi('green','HELP #namespace# [command]') & cr;
		if(namespace == '' && command == '') {
			for(var commandName in commands['']) {
				var helpText = commands[''][commandName].hint;
				result &= chr(9) & shell.ansi('cyan',commandName) & ' : ' & helpText & cr;
			}
			for(var ns in namespaceHelp) {
				var helpText = namespaceHelp[ns];
				result &= chr(9) & shell.ansi('black,cyan_back',ns) & ' : ' & helpText & cr;
			}
		} else {
			if(!isNull(commands[namespace][command])) {
				result &= getCommandHelp(namespace,command);
			} else if (!isNull(commands[namespace])){
				var helpText = namespaceHelp[namespace];
				result &= chr(9) & shell.ansi('cyan',namespace) & ' : ' & helpText & cr;
				for(var commandName in commands[namespace]) {
					var helpText = commands[namespace][commandName].hint;
					result &= chr(9) & shell.ansi('cyan',commandName) & ' : ' & helpText & cr;
				}
			} else {
				shell.printError({message:'No help found for #namespace# #command#'});
				return '';
			}
		}
		return result;
	}

	/**
	 * get command help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	private function getCommandHelp(String namespace='', String command='')  {
		var result ='';
		var metadata = commands[namespace][command];
		result &= chr(9) & shell.ansi('cyan',command) & ' : ' & metadata.hint & cr;
		result &= chr(9) & shell.ansi('magenta','Arguments') & cr;
		for(var param in metadata.parameters) {
			result &= chr(9);
			if(param.required)
				result &= shell.ansi('red','required ');
			result &= param.type & ' ';
			result &= shell.ansi('magenta',param.name);
			if(!isNull(param.default))
				result &= '=' & param.default & ' ';
			if(!isNull(param.hint))
				result &= ' (#param.hint#)';
		 	result &= cr;
		}
		return result;
	}

	
}
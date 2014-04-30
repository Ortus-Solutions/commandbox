/**
 * completion handler
 * @author Denny Valliant
 **/
component output="false" persistent="false" {

	// command list
	commandlist = createObject("java","java.util.TreeSet");

	/**
	 * constructor
	 * @commandHandler.hint CommandHandler this completor is attached to
	 **/
	function init(commandHandler) {
		variables.commandHandler = arguments.commandHandler;
		variables.commandlist.addAll(commandHandler.listCommands().split(','));
		variables.commands = commandHandler.getCommands();
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @cursor.hint cursor position
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	function complete(String buffer, numeric cursor, candidates)  {
		var start = isNull(buffer) ? "" : buffer;
		var args = rematch("'.*?'|"".*?""|\S+",start);
		var prefix = args.size() > 0 && structKeyExists(commands,args[1]) ? args[1] : "";
		var startIndex = 0;
		var isArgument = false;
		var lastArg = args.size() > 0 ? args[args.size()] : "";
		variables.partialCompletion = false;
		if(prefix eq "") {
			command = args.size() > 0 ? args[1] : "";
		} else {
			if(arrayLen(args) >= 2) {
				command = args[2];
			} else if(!StructKeyExists(commands,prefix)) {
				return len(start);
			}
		}

		if(args.size() == 0 || arrayLen(args) == 1 && !start.endsWith(" ")) {
			// starting to type the prefix or command
        	candidates.clear();
	        for (var i = commandlist.iterator(); i.hasNext();) {
	            var can = i.next();
	            if (can.startsWith(start)) {
		            candidates.add(can);
	            }
	        }
		} else if (arrayLen(args) == 1 && start.endsWith(" ")) {
			// add prefix command list or command parameters
			if(len(prefix) > 0) {
				for(var param in commands[prefix]) {
	            	candidates.add(param);
				}
			} else {
				if(!StructKeyExists(commands,prefix) || !StructKeyExists(commands[prefix],command)) {
					return len(start);
				}
				for(var param in commands[prefix][command].parameters) {
	            	candidates.add(param.name);
				}
				isArgument = true;
			}
			startIndex = len(start);
		} else if(len(prefix) && arrayLen(args) == 2 && !start.endsWith(" ")) {
			// prefix command list
			for(var param in commands[prefix]) {
	            if (param.startsWith(lastArg)) {
            		candidates.add(param);
	            }
			}
			startIndex = len(start) - len(lastArg);
		} else if(arrayLen(args) > 1) {
			var parameters = "";
			var lastArg = args[arrayLen(args)];
			isArgument = true;
			parameters = commands[prefix][command].parameters;
			for(var param in parameters) {
				if(!start.endsWith(" ") && lastArg.startsWith("#param.name#=")) {
					var paramType = param.type;
					var paramSoFar = listRest(lastArg,"=");
					paramValueCompletion(param.name, paramType, paramSoFar, candidates);
					startIndex = len(start) - len(paramSoFar);
					isArgument = false;
				} else {
		            if (param.name.startsWith(lastArg) || start.endsWith(" ")) {
		            	if(!findNoCase(param.name&"=", start)) {
		            		candidates.add(param.name);
		            	}
		            }
					startIndex = start.endsWith(" ") || findNoCase("=",lastArg) ? len(start) : len(start) - len(lastArg);
					isArgument = true;
				}
			}
		}
        if (candidates.size() == 1 && !partialCompletion) {
        	can = isArgument ? candidates.first() & "=" : candidates.first() & " ";
        	candidates.clear();
        	candidates.add(can);
        }
        return (candidates.size() == 0) ? (-1) : startIndex;
	}

	/**
	 * populate completion candidates for parameter values
	 * @paramName.hint param name
	 * @paramType.hint type of parameter (boolean, etc.)
	 * @paramSoFar.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function paramValueCompletion(String paramName, String paramType, String paramSoFar, required candidates) {
		switch(paramType) {
			case "Boolean" :
           		addCandidateIfMatch("true",paramSoFar,candidates);
           		addCandidateIfMatch("false",paramSoFar,candidates);
				break;
		}
		switch(paramName) {
			case "directory" :
			case "destination" :
           		directoryCompletion(paramSoFar,candidates);
				break;
			case "file" :
           		fileCompletion(paramSoFar,candidates);
				break;
		}
	}

	/**
	 * populate directory parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function directoryCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandHandler.getShell().pwd();
		}
		var files = directoryList(getDirectoryFromPath(startsWith));
		for(file in files) {
			if(file.startsWith(startsWith)) {
				if(directoryExists(file))
					candidates.add(file&"/");
			}
		}
		variables.partialCompletion = true;
	}


	/**
	 * populate file parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function fileCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandHandler.getShell().pwd();
		}
		var files = directoryList(getDirectoryFromPath(startsWith));
		for(file in files) {
			if(file.startsWith(startsWith)) {
				if(fileExists(file))
					candidates.add(file);
			}
		}
	}

	/**
	 * add a value completion candidate if it matches what was typed so far
	 * @match.hint text to compare as match
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function addCandidateIfMatch(required match, required startsWith, required candidates) {
		match = lcase(match);
		startsWith = lcase(startsWith);
		if(match.startsWith(startsWith) || len(startsWith) == 0) {
			candidates.add(match);
		}
	}

}
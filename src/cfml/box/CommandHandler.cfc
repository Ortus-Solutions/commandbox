/**
 * Command handler
 * @author Denny Valliant
 **/
component output="false" persistent="false" {

	commands = {};
	commandAliases = {};
	namespaceHelp = {};
	thisdir = getDirectoryFromPath(getMetadata(this).path);
	System = createObject("java", "java.lang.System");
	cr = System.getProperty("line.separator");

	/**
	 * constructor
	 * @shell.hint shell this command handler is attached to
	 **/
	function init(required shell) {
		variables.shell = shell;
		reader = shell.getReader();
        var completors = createObject("java","java.util.LinkedList");
		initCommands();
		var completor = createDynamicProxy(new Completor(this), ["jline.Completor"]);
        reader.addCompletor(completor);
		return this;
	}

	/**
	 * initialize the commands
	 **/
	function initCommands() {
		var varDirs = DirectoryList(thisdir&"/namespace", false, "name");
		for(var dir in varDirs){
			if(listLast(dir,".") eq "cfc") {
				loadCommands("","namespace.#listFirst(dir,'.')#");
			} else {
				loadCommands(dir,"namespace.#dir#.#dir#");
			}
		}
	}

	/**
	 * load commands into a namespace from a cfc
	 * @namespace.hint namespace these commands belong in
	 * @cfc.hint cfc to read for commands
	 **/
	function loadCommands(namespace,cfc) {
		var cfc = createObject(cfc).init(shell);
		var cfcMeta = getMetadata(cfc);
		for(var fun in cfcMeta.functions) {
			if(fun.name != "init" && fun.access != "private") {
				var commandname = isNull(fun["command.name"]) ? fun.name : fun["command.name"];
				var aliases = isNull(fun["command.aliases"]) ? [] : listToArray(fun["command.aliases"]);
				for(var alias in aliases) {
					commandAliases[namespace][alias]=commandname;
				}
				commands[namespace][commandname].functionName = fun.name;
				commands[namespace][commandname].cfc = cfc;
				commands[namespace][commandname].hint = fun.hint;
				for(var param in fun.parameters) {
					if(isNull(param.hint)) {
						param.hint = "No help available";
					}
				}
				commands[namespace][commandname].parameters = fun.parameters;
			}
		}
		if(namespace != "") {
			namespaceHelp[namespace] = !isNull(cfcMeta.hint) ? cfcMeta.hint : "";
		}
	}

	/**
	 * get help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	function help(String namespace="", String command="")  {
		if(namespace != "" && command == "") {
			if(!isNull(commands[""][namespace])) {
				command = namespace;
				namespace = "";
			} else if(!isNull(commandAliases[""][namespace])) {
				command = commandAliases[""][namespace];
				namespace = "";
			} else if (isNull(commands[namespace])) {
				shell.printError({message:"No help found for #namespace#"});
				return "";
			}
		}
		var result = shell.ansi("green","HELP #namespace# [command]") & cr;
		if(namespace == "" && command == "") {
			for(var commandName in commands[""]) {
				var helpText = commands[""][commandName].hint;
				result &= chr(9) & shell.ansi("cyan",commandName) & " : " & helpText & cr;
			}
			for(var ns in namespaceHelp) {
				var helpText = namespaceHelp[ns];
				result &= chr(9) & shell.ansi("black,cyan_back",ns) & " : " & helpText & cr;
			}
		} else {
			if(!isNull(commands[namespace][command])) {
				result &= getCommandHelp(namespace,command);
			} else if (!isNull(commands[namespace])){
				var helpText = namespaceHelp[namespace];
				result &= chr(9) & shell.ansi("cyan",namespace) & " : " & helpText & cr;
				for(var commandName in commands[namespace]) {
					var helpText = commands[namespace][commandName].hint;
					result &= chr(9) & shell.ansi("cyan",commandName) & " : " & helpText & cr;
				}
			} else {
				shell.printError({message:"No help found for #namespace# #command#"});
				return "";
			}
		}
		return result;
	}

	/**
	 * get command help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	private function getCommandHelp(String namespace="", String command="")  {
		var result ="";
		var metadata = commands[namespace][command];
		result &= chr(9) & shell.ansi("cyan",command) & " : " & metadata.hint & cr;
		result &= chr(9) & shell.ansi("magenta","Arguments") & cr;
		for(var param in metadata.parameters) {
			result &= chr(9);
			if(param.required)
				result &= shell.ansi("red","required ");
			result &= param.type & " ";
			result &= shell.ansi("magenta",param.name)
			if(!isNull(param.default))
				result &= "=" & param.default & " ";
			if(!isNull(param.hint))
				result &= " (#param.hint#)";
		 	result &= cr;
		}
		return result;
	}

	/**
	 * return the shell
 	 **/
	function getShell() {
		return variables.shell;
	}

	/**
	 * run a command line
	 * @line.hint line to run
 	 **/
	function runCommandline(line) {
		var args = rematch("'.*?'|"".*?""|\S+",line);
		var namespace = structKeyExists(commands,args[1]) ? args[1] : "";
 		if(namespace eq "") {
			command = args[1];
			arrayDeleteAt(args,1);
		} else {
			if(arrayLen(args) >= 2) {
				command = args[2];
				arrayDeleteAt(args,1);
				arrayDeleteAt(args,1);
			} else {
				if(!StructKeyExists(commands,namespace)) {
					if(!isNull(commandAliases[""][command])) {
						command = commandAliases[""][command];
						continue;
					}
					shell.printError({message:"'#namespace#' is unknown.  Did you mean one of these: #listCommands()#?"});
					return;
				}
				if(structKeyExists(commands[namespace],namespace)) {
					command = namespace;
					arrayDeleteAt(args,1);
				} else {
					return "available actions: #structKeyList(commands[namespace])#";
				}
			}
		}
		if(isNull(commands[namespace][command])) {
			if(!isNull(commandAliases[namespace][command])) {
				command = commandAliases[namespace][command];
			} else {
				shell.printError({message:"'#namespace# #command#' is unknown.  Did you mean one of these: #structKeyList(commands[namespace])#?"});
				return;
			}
		}
		args = isNull(args) ? [] : args;
		var namedArgs = {};
		var requiredParams = [];
		for(var param in commands[namespace][command].parameters) {
        	if(param.required) {
				arrayAppend(requiredParams,param);
        	}
           	for(var arg in args) {
           		if(findNoCase(param.name&"=",arg)) {
            		namedArgs[param.name] = replaceNoCase(arg,"#param.name#=","");
		        	if(param.required) {
            			arrayDelete(requiredParams,param);
		        	}
           		}
           	}
           	for(var x = arrayLen(requiredParams); x gt arrayLen(args); x--) {
           		var arg = shell.ask("Enter #requiredParams[x].name# (#requiredParams[x].hint#) : ");
    			arrayAppend(args,arg);
           	}
		}
		if(len(StructKeyList(namedArgs))) {
			return callCommand(namespace,command,namedArgs);
		}
		return callCommand(namespace,command,args);
	}

	/**
	 * call a command
 	 **/
	function callCommand(namespace, command, args) {
		var functionName = commands[namespace][command].functionName;
		var runCFC = commands[namespace][command].cfc;
		args = isNull(args) ? [] : args;
		if(args.size()) {
			return runCFC[functionName](argumentCollection=args);
		} else {
			return runCFC[functionName]();
		}
	}

	/**
	 * return a list of base commands (includes namespaces)
 	 **/
	function listCommands() {
		return listAppend(structKeyList(commands[""]),structKeyList(commands));
	}

	/**
	 * return the namespaced command structure
 	 **/
	function getCommands() {
		return commands;
	}

}
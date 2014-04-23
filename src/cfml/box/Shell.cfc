/**
 * Box Shell
 * @author Denny Valliant
 **/
component {

	System = createObject("java", "java.lang.System");
	ANSIBuffer = createObject("java", "jline.ANSIBuffer");
	ANSICodes = createObject("java", "jline.ANSIBuffer$ANSICodes");
    StringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
	keepRunning = true;
    reloadshell = false;
	script = "";
	initialDirectory = createObject("java","java.lang.System").getProperty("user.dir");
	pwd = initialDirectory;
	cr = System.getProperty("line.separator");

	/**
	 * constructor
	 * @inStram.hint input stream if running externally
	 * @printWriter.hint output if running externally
	 **/
	function init(inStream, printWriter) {
		if(isNull(printWriter)) {
			if(findNoCase("windows",server.os.name)) {
				variables.ansiOut = createObject("java","org.fusesource.jansi.AnsiConsole").out;
        		var printWriter = createObject("java","java.io.PrintWriter").init(
        			createObject("java","java.io.OutputStreamWriter").init(variables.ansiOut,
        			// default to Cp850 encoding for Windows
        			System.getProperty("jline.WindowsTerminal.output.encoding", "Cp850"))
        			);
				var FileDescriptor = createObject("java","java.io.FileDescriptor").init();
		    	inStream = createObject("java","java.io.FileInputStream").init(FileDescriptor.in);
				reader = createObject("java","jline.ConsoleReader").init(inStream,printWriter);
			} else {
				//new PrintWriter(OutputStreamWriter(System.out,System.getProperty("jline.WindowsTerminal.output.encoding",System.getProperty("file.encoding"))));
		    	reader = createObject("java","jline.ConsoleReader").init();
			}
		} else {
			if(isNull(arguments.inStream)) {
		    	var FileDescriptor = createObject("java","java.io.FileDescriptor").init();
		    	inStream = createObject("java","java.io.FileInputStream").init(FileDescriptor.in);
			}
	    	reader = createObject("java","jline.ConsoleReader").init(inStream,printWriter);
		}
		variables.commandHandler = new CommandHandler(this);
		variables.shellPrompt = ansi("cyan","box> ");
    	return this;
	}

	/**
	 * returns the console reader
	 **/
	function getReader() {
    	return reader;
	}

	/**
	 * sets exit flag
	 **/
	function exit() {
    	keepRunning = false;
		return "Peace out!";
	}

	/**
	 * sets reload flag, relaoded from shell.cfm
	 * @clear.hint clears the screen after reload
 	 **/
	function reload(Boolean clear=true) {
		if(clear) {
			reader.clearScreen();
		}
		reloadshell = true;
    	keepRunning = false;
	}

	/**
	 * returns the current console text
 	 **/
	function getText() {
    	return reader.getCursorBuffer().toString();
	}

	/**
	 * sets prompt
	 * @text.hint prompt text to set
 	 **/
	function setPrompt(text="") {
		if(text eq "") {
			text = variables.shellPrompt;
		} else {
			variables.shellPrompt = text;
		}
		reader.setDefaultPrompt(variables.shellPrompt);
		return "set prompt";
	}

	/**
	 * ask the user a question and wait for response
	 * @message.hint message to prompt the user with
 	 **/
	function ask(message) {
		var input = "";
		try {
			input = reader.readLine(message);
		} catch (any e) {
			printError(e);
		}
		reader.setDefaultPrompt(variables.shellPrompt);
		return input;
	}

	/**
	 * clears the console
 	 **/
	function clearScreen() {
		reader.clearScreen();
	}

	/**
	 * Converts HTML into plain text
	 * @html.hint HTML to convert
  	 **/
	function unescapeHTML(required html) {
    	var text = StringEscapeUtils.unescapeHTML(html);
    	text = replace(text,"<" & "br" & ">","","all");
       	return text;
	}

	/**
	 * Converts HTML into ANSI text
	 * @html.hint HTML to convert
  	 **/
	function HTML2ANSI(required html) {
    	var text = replace(unescapeHTML(html),"<" & "br" & ">","","all");
    	var t="b";
    	if(len(trim(text)) == 0) {
    		return "";
    	}
    	var matches = REMatch('(?i)<#t#[^>]*>(.+?)</#t#>', text);
    	text = ansifyHTML(text,"b","bold");
    	text = ansifyHTML(text,"em","underline");
       	return text;
	}

	/**
	 * Converts HTML matches into ANSI text
	 * @text.hint HTML to convert
	 * @tag.hint HTML tag name to replace
	 * @ansiCode.hint ANSI code to replace tag with
  	 **/
	private function ansifyHTML(text,tag,ansiCode) {
    	var t=tag;
    	var matches = REMatch('(?i)<#t#[^>]*>(.+?)</#t#>', text);
    	for(var match in matches) {
    		var boldtext = ansi(ansiCode,reReplaceNoCase(match,"<#t#[^>]*>(.+?)</#t#>","\1"));
    		text = replace(text,match,boldtext,"one");
    	}
    	return text;
	}

	/**
	 * returns the current directory
  	 **/
	function pwd() {
    	return pwd;
	}

	/**
	 * changes the current directory
	 * @directory.hint directory to CD to
  	 **/
	function cd(directory="") {
		directory = replace(directory,"\","/","all");
		if(directory=="") {
			pwd = initialDirectory;
		} else if(directory=="."||directory=="./") {
			// do nothing
		} else if(directoryExists(directory)) {
	    	pwd = directory;
		} else {
			return "cd: #directory#: No such file or directory";
		}
		return pwd;
	}

	/**
	 * Adds ANSI attributes to string
	 * @attribute.hint list of ANSI codes to apply
	 * @string.hint string to apply ANSI to
  	 **/
	function ansi(required attribute, required string) {
		var textAttributes =
		{"off":0,
		 "none":0,
		 "bold":1,
		 "underscore":4,
		 "blink":5,
		 "reverse":7,
		 "concealed":8,
		 "black":30,
		 "red":31,
		 "green":32,
		 "yellow":33,
		 "blue":34,
		 "magenta":35,
		 "cyan":36,
		 "white":37,
		 "black_back":40,
		 "red_back":41,
		 "green_back":42,
		 "yellow_back":43,
		 "blue_back":44,
		 "magenta_back":45,
		 "cyan_back":46,
		 "white_back":47,
		}
		var ansiString = "";
		for(var attrib in listToArray(attribute)) {
			ansiString &= ANSICodes.attrib(textAttributes[attrib]);
		}
		ansiString &= string & ANSICodes.attrib(textAttributes["off"]);
    	return ansiString;
	}

	/**
	 * prints string to console
	 * @string.hint string to print (handles complex objects)
  	 **/
	function print(required string) {
		if(!isSimpleValue(string)) {
			systemOutput("[COMPLEX VALUE]\n");
			writedump(var=string, output="console");
			string = "";
		}
    	return reader.printString(string);
	}

	/**
	 * runs the shell thread until exit flag is set
	 * @input.hint command line to run if running externally
  	 **/
    function run(input="") {
        var mask = "*";
        var trigger = "su";
        reloadshell = false;

		try{
	        if (input != "") {
	        	input &= chr(10);
	        	var inStream = createObject("java","java.io.ByteArrayInputStream").init(input.getBytes());
	        	reader.setInput(inStream);
	        }
	        reader.setBellEnabled(false);
	        //reader.setDebug(new PrintWriter(new FileWriter("writer.debug", true)));

	        var line ="";
	        keepRunning = true;
			reader.setDefaultPrompt(shellPrompt);

	        while (keepRunning) {
				if(input != "") {
					keepRunning = false;
				}
				reader.printNewLine();
				try {
		        	line = reader.readLine();
				} catch (any er) {
					printError(er);
					// reload();
					continue;
				}
				if(trim(line) == "reload") {
					reload();
					continue;
				}
	            //reader.printString("======>" & line);
	            // If we input the special word then we will mask
	            // the next line.
	            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
	                line = reader.readLine("password> ", javacast("char",mask));
	            }
				var args = rematch("'.*?'|"".*?""|\S+",line);
				if(args.size() == 0 || len(trim(line))==0) continue;
				try{
					var result = commandHandler.runCommandLine(line);
					result = isNull(result) ? "" : print(result);
				} catch (any e) { printError(e); }
	        }
	        if(structKeyExists(variables,"ansiOut")) {
	        	variables.ansiOut.close();
	        }
	        //out.close();
		} catch (any e) {
			printError(e);
	        if(structKeyExists(variables,"ansiOut")) {
	        	variables.ansiOut.close();
	        }
		}
		return reloadshell;
    }

	/**
	 * display help information
	 * @namespace.hint namespace (or namespaceless command) to get help for
 	 * @command.hint command to get help for
 	 **/
	function help(String namespace="", String command="")  {
		return commandHandler.help(namespace,command);
	}

	/**
	 * print an error to the console
	 * @err.hint Error object to print (only message is required)
  	 **/
	function printError(required err) {
		reader.printString(ansi("red","ERROR: ") & HTML2ANSI(err.message));
		if (structKeyExists( err, 'tagcontext' )) {
			var lines=arrayLen( err.tagcontext );
			if (lines != 0) {
				for(idx=1; idx<=lines; idx++) {
					tc = err.tagcontext[ idx ];
					if (len( tc.codeprinthtml )) {
						isFirst = ( idx == 1 );
						isFirst ? reader.printString(ansi("red","#tc.template#: line #tc.line#")) : reader.printString(ansi("magenta","#ansi('bold','called from ')# #tc.template#: line #tc.line#"));
						reader.printNewLine();
						reader.printString(ansi("blue",HTML2ANSI(tc.codeprinthtml)));
					}
				}
			}
		}
		reader.printNewLine();
	}

}
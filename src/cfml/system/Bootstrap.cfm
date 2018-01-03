<cfsilent>
<!---
*********************************************************************************
 Copyright Since 2014 CommandBox by Ortus Solutions, Corp
 www.coldbox.org | www.ortussolutions.com
********************************************************************************
@author Brad Wood, Luis Majano, Denny Valliant

I bootstrap CommandBox up, create the shell and get it running.
I am a CFM because the CLI seems to need a .cfm file to call
This file will stay running the entire time the shell is open
--->
<cfset variables.wireBox = application.wireBox>
<cfsetting requesttimeout="86399913600" /><!--- 999999 days --->
<!---Display this banner to users--->
<cfoutput><cfsavecontent variable="banner">#chr( 27 )#[32m#chr( 27 )#[1m
   _____                                          _ ____
  / ____|                                        | |  _ \
 | |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
 | |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
 | |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  <
  \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ #chr( 27 )#[0m  v@@version@@

#chr( 27 )#[1mWelcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.#chr( 27 )#[0m

</cfsavecontent></cfoutput>
<cfscript>
	system 	= createObject( "java", "java.lang.System" );
	args 	= system.getProperty( "cfml.cli.arguments" );
	argsArray = deserializeJSON( system.getProperty( "cfml.cli.argument.array" ) );

	// System.in is usually the keyboard input, but if the output of another command or a file
	// was piped into CommandBox, System.in will represent that input.  Wrap System.in
	// in a buffered reader so we can check it.
	inputStreamReader = createObject( 'java', 'java.io.InputStreamReader' ).init( system.in );
	bufferedReader = createObject( 'java', 'java.io.BufferedReader' ).init( inputStreamReader );

	// Verify if we can run CommandBox Java v. 1.7+
	if( !findNoCase( "1.8", server.java.version ) ){
		// JLine isn't loaded yet, so I have to use systemOutput() here.
		systemOutput( "The Java Version you have (#server.java.version#) is not supported by CommandBox. Please install a Java JRE/JDK 1.8." );
		sleep( 5000 );
		abort;
	}

	// Check if we are called with an inline command
	if( !isNull( args ) && trim( args ) != "" ){

		// Create the shell
		shell = wireBox.getInstance( name='Shell', initArguments={ asyncLoad=false } );
		shell.setShellType( 'command' );
		interceptorService =  shell.getInterceptorService();

		interceptData = { shellType=shell.getShellType(), args=argsArray, banner=banner };
		interceptorService.announceInterception( 'onCLIStart', interceptData );

 		piped = [];
 		hasPiped = false;
	 	// If data is piped to CommandBox, it will be in this buffered reader
	 	while ( bufferedReader.ready() ) {
	 		// Read  all the lines and append them together.
	 		piped.append( bufferedReader.readLine() );
 			hasPiped = true;
	 	}

	 	// If data was piped via standard input
	 	if( hasPiped ) {
		 	// Concat lines back together
			piped = arrayToList( piped, chr( 10 ) );
			shell.callCommand( command=argsArray, piped=piped, initialCommand=true );
		} else {
			shell.callCommand( command=argsArray, initialCommand=true );
		}

		// flush console
		shell.getReader().flush();
	// "box" was called all by itself with no commands
	} else {
		// If the standard input has content waiting, cut the chit chat and just run the commands so we can exit.
		silent = bufferedReader.ready();
		inStream = system.in;

		// If we're piping in data, let's grab it and treat it as commands.
		// system.in should work directly, but Windows was blocking forever and not reading the InputStream
		// So we'll create our own input stream with a line break at the end
		if( silent ) {
	 		piped = [];
		 	// If data is piped to CommandBox, it will be in this buffered reader
		 	while ( bufferedReader.ready() ) {
		 		// Read  all the lines and append them together.
		 		piped.append( bufferedReader.readLine() );
		 	}
		 	// Build a string with a line for each line read from the standard input.
		 	piped = piped.toList( chr( 10 ) ) & chr( 10 );
    		inStream = createObject("java","java.io.ByteArrayInputStream").init(piped.getBytes());
		}

		// Create the shell
		shell = application.wirebox.getInstance( name='Shell', initArguments={ asyncLoad=!silent, inStream=inStream, outputStream=system.out } );

		shell.setShellType( 'interactive' );
		interceptorService =  shell.getInterceptorService();

		interceptData = { shellType=shell.getShellType(), args=argsArray, banner=banner };
		interceptorService.announceInterception( 'onCLIStart', interceptData );

		if( !silent ) {
			// Output the welcome banner
			shell.printString( replace( interceptData.banner, '@@version@@', shell.getVersion() ) );
		}

		// Running the "reload" command will enter this while loop once
		while( shell.run( silent=silent ) ){
			clearScreen = shell.getDoClearScreen();

			interceptorService.announceInterception( 'onCLIExit' );
			if( clearScreen ){
				shell.clearScreen();
			}
				
			// Shut down the shell, which includes cleaing up JLine
			shell.shutdown();

			// Clear all caches: template, ...
			SystemCacheClear( "all" );
			shell = javacast( "null", "" );

			// reload wirebox
			wireBox.shutdown();
			new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
			variables.wireBox = application.wireBox;


			// startup a new shell
			shell = wireBox.getInstance( 'Shell' );
			interceptorService =  shell.getInterceptorService();
			shell.setShellType( 'interactive' );
			interceptData = { shellType=shell.getShellType(), args=[], banner=banner };
			interceptorService.announceInterception( 'onCLIStart', interceptData );

			if( clearScreen ){
				// Output the welcome banner
				shell.printString( replace( interceptData.banner, '@@version@@', shell.getVersion() ) );
			}

		}
	}

	interceptorService.announceInterception( 'onCLIExit' );

    system.runFinalization();
    system.gc();
</cfscript>
</cfsilent>

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
<cfsetting requesttimeout="999999" />
<!---Display this banner to users--->
<cfsavecontent variable="banner">
  _____                                          _ ____
 / ____|                                        | |  _ \
| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  <
 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v@@version@@

Welcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.
</cfsavecontent>
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
	if( findNoCase( "1.6", server.java.version ) ){
		systemOutput( "The Java Version you have (#server.java.version#) is not supported by CommandBox. Please install a Java JRE/JDK 1.7+" );
		sleep( 5000 );
		abort;
	}

	// Check if we are called with an inline command
	if( !isNull( args ) && trim( args ) != "" ){
		
		// Create the shell
		shell = wireBox.getInstance( name='Shell', initArguments={ asyncLoad=false } );
		interceptorService =  shell.getInterceptorService();
		
		interceptData = { shellType='command', args=argsArray, banner=banner };
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
			shell.callCommand( command=argsArray, piped=piped );
		} else {
			shell.callCommand( command=argsArray );
		}
		
		// flush console
		shell.getReader().flush();
	} else {
		// If the standard input has content waiting, cut the chit chat and just run the commands so we can exit.
		silent = bufferedReader.ready();
		
		// Create the shell
		shell = wireBox.getInstance( name='Shell', initArguments={ asyncLoad=!silent } );
		interceptorService =  shell.getInterceptorService();
		
		interceptData = { shellType='interactive', args=argsArray, banner=banner };
		interceptorService.announceInterception( 'onCLIStart', interceptData );
		
		if( !silent ) {
			// Output the welcome banner
			systemOutput( replace( interceptData.banner, '@@version@@', shell.getVersion() ) );
		}
		
		// Running the "reload" command will enter this while loop once
		while( shell.run( silent=silent ) ){
			interceptorService.announceInterception( 'onCLIExit' );
			// Clear all caches: template, ...
			SystemCacheClear( "all" );
			shell = javacast( "null", "" );
			
			// reload wirebox
			wireBox.shutdown();
			new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
			variables.wireBox = application.wireBox;
			
			// startup a new shell
			shell = wireBox.getInstance( 'Shell' );
			interceptorService.announceInterception( 'onCLIStart', { shellType='interactive', args=argsArray } );
		}
	}
	
	interceptorService.announceInterception( 'onCLIExit' );

    system.runFinalization();
    system.gc();
</cfscript>
</cfsilent>
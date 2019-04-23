<cfsilent><cftry>
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


<cfset system = createObject( "java", "java.lang.System" )>
<cfset system.setProperty( 'exitCode', '0' )>
<cfset mappings = getApplicationSettings().mappings>

<!--- Move everything over to this mapping which is the "root" of our app --->
<cfset CFMLRoot = expandPath( getDirectoryFromPath( getCurrentTemplatePath() ) & "../" ) >
<cfset mappings[ '/commandbox' ]		= CFMLRoot >
<cfset mappings[ '/commandbox-home' ]	= system.getProperty( 'cfml.cli.home' ) >
<cfset mappings[ '/wirebox' ]			= CFMLRoot & 'system/wirebox' >
	
<cfapplication 
	action="update"
	name 				= "CommandBox CLI"
	sessionmanagement 	= "false"
	applicationTimeout = "#createTimeSpan( 999999, 0, 0, 0 )#"
	mappings="#mappings#">

<!--- 
	Workaround to snuff out annoying ESAPI warnings in the console.
	If necessary, move this to the Java loader.  Right now Lucee doesn't seem to hit any ESAPI libs until CommandBox is loaded. 
--->
<cfset system.setProperty( 'org.owasp.esapi.opsteam', expandPath( '/commandbox/system/config/ESAPI.properties' ) )>
<cfset system.setProperty( 'org.owasp.esapi.devteam', expandPath( '/commandbox/system/config/ESAPI.properties' ) )>

<cfset variables.wireBox = new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' )>

<cfsetting requesttimeout="86399913600" /><!--- 999999 days --->

<cffunction name="getBanner"> 
	<!---Display this banner to users--->
	<cfscript>
	 	
		var esc = chr( 27 );
		var caps = createObject( 'java', 'org.jline.utils.InfoCmp$Capability' );
		// See how many colors this terminal supports
		var numColors = shell.getReader().getTerminal().getNumericCapability( caps.max_colors ) ?: 0;
	
		// Windows cmd gets solid blue
		if( !isNull( numColors ) && numColors < 256 ) {
			l1 = l2 = l3 = l4 = l5 = '#esc#[38;5;14m';
		// Terminals with 256 color support get pretty colors
		} else {
			l1 = '#esc#[38;5;45m';
			l2 = '#esc#[38;5;39m';
			l3 = '#esc#[38;5;33m';
			l4 = '#esc#[38;5;27m';
			l5 = '#esc#[38;5;21m';
		}
	
	</cfscript>
<cfoutput><cfsavecontent variable="banner">	
#l1##esc#[1m   ______                                          ______            
#l2##esc#[1m  / ____/___  ____ ___  ____ ___  ____ _____  ____/ / __ )____  _  __
#l3##esc#[1m / /   / __ \/ __ `__ \/ __ `__ \/ __ `/ __ \/ __  / __  / __ \| |/_/
#l4##esc#[1m/ /___/ /_/ / / / / / / / / / / / /_/ / / / / /_/ / /_/ / /_/ />  <  
#l5##esc#[1m\____/\____/_/ /_/ /_/_/ /_/ /_/\__,_/_/ /_/\__,_/_____/\____/_/|_| (R)  #esc#[0m#esc#[1mv@@version@@  

#esc#[0m#esc#[38;5;196m@@quote@@

#esc#[38;5;15mWelcome to CommandBox!
</cfsavecontent></cfoutput>
	<cfset var banner = replace( banner, '@@version@@', shell.getVersion().replace( '@build' & '.version@+@build' & '.number@', '1.2.3' ) )>
	<cfset var quotes = fileRead( 'Quotes.txt' ).listToArray( chr( 13 ) & chr( 10 ) )>
	<cfset var quote = quotes[ randRange( 1, quotes.len() ) ]>
	<cfset banner = replace( banner, '@@quote@@', repeatString( ' ', max( 77-quote.len(), 1 ) ) & quote )>
		
	<cfreturn banner>
</cffunction>
<cfscript>
	args 	= system.getProperty( "cfml.cli.arguments" );
	argsArray = deserializeJSON( system.getProperty( "cfml.cli.argument.array" ) );

	// Verify if we can run CommandBox Java v. 1.7+
	if( !findNoCase( "1.8", server.java.version ) && 0 ){
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

		if( argsArray.len() == 1 && argsArray[ 1 ].listLen( ' ' ) > 1 ) {
			parser = wirebox.getInstance( 'parser' );
			argsArray = parser.tokenizeInput( argsArray[ 1 ] );
		}

		interceptData = { shellType=shell.getShellType(), args=argsArray, banner=getBanner() };
		interceptorService.announceInterception( 'onCLIStart', interceptData );

		shell.callCommand( command=argsArray, initialCommand=true );

		// flush console
		shell.getReader().flush();
		
	// "box" was called all by itself with no commands
	} else {

		// System.in is usually the keyboard input, but if the output of another command or a file
		// was piped into CommandBox, System.in will represent that input.  Wrap System.in
		// in a buffered reader so we can check it.
		inputStreamReader = createObject( 'java', 'java.io.InputStreamReader' ).init( system.in );
		bufferedReader = createObject( 'java', 'java.io.BufferedReader' ).init( inputStreamReader );
		
		// If the standard input has content waiting, cut the chit chat and just run the commands so we can exit.
		silent = bufferedReader.ready();
		inStream = system.in;

		// Create the shell
		shell = application.wirebox.getInstance( name='Shell', initArguments={ asyncLoad=!silent, inStream=inStream, outputStream=system.out } );

		shell.setShellType( 'interactive' );
		interceptorService =  shell.getInterceptorService();

		interceptData = { shellType=shell.getShellType(), args=argsArray, banner=getBanner() };
		interceptorService.announceInterception( 'onCLIStart', interceptData );

		if( !silent ) {
			// Output the welcome banner
			shell.printString( interceptData.banner );
		}

		// Running the "reload" command will enter this while loop once
		while( shell.run( silent=silent ) ){
			clearScreen = shell.getDoClearScreen();
			
			interceptorService.announceInterception( 'onCLIExit' );
			if( clearScreen ){
				shell.clearScreen();
			}
			
			// Wipe out cached metadata on reload.
			wirebox.getCacheBox().getCache( 'metadataCache' ).clearAll();
				
			// Shut down the shell, which includes cleaing up JLine
			shell.shutdown();

			// Clear all caches: template, ...
			SystemCacheClear( "all" );
			shell = javacast( "null", "" );

			// reload wirebox
			wireBox.shutdown();
			variables.wireBox = new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );

			// startup a new shell
			shell = wireBox.getInstance( 'Shell' );
			interceptorService =  shell.getInterceptorService();
			shell.setShellType( 'interactive' );
			interceptData = { shellType=shell.getShellType(), args=[], banner=getBanner() };
			interceptorService.announceInterception( 'onCLIStart', interceptData );

			if( clearScreen ){
				// Output the welcome banner
				shell.printString( interceptData.banner );
			}

		}
	}

	interceptorService.announceInterception( 'onCLIExit' );

    system.runFinalization();
    system.gc();
</cfscript>

	<cfcatch type="any">
		<cfscript>
			
			try {
				if( isDefined( 'wirebox' ) ) {
					wirebox.getCacheBox().getCache( 'metadataCache' ).clearAll();
				}
			} catch( any e) {
			}
			
			system.setProperty( 'cfml.cli.exitCode', '1' );
	
			// Try to log this to LogBox
			try {
	    		application.wireBox.getLogBox().getRootLogger().error( '#exception.message# #exception.detail ?: ''#', exception.stackTrace );
				application.wireBox.getInstance( 'interceptorService' ).announceInterception( 'onException', { exception=exception } );
	    	// If it fails no worries, LogBox just probably isn't loaded yet.
			} catch ( Any e ) {}
			
			verboseErrors = true;
			try{
				verboseErrors = wirebox.getInstance( 'configService' ).getSetting( 'verboseErrors', false );
			} catch( any e ) {}
	
			// Give nicer message to user
			err = cfcatch;
	    	CR = chr( 10 );    	
			// JLine may not be loaded yet, so I have to use systemOutput() here.
	    	systemOutput( 'BOOM GOES THE DYNAMITE!!', true );
	    	systemOutput( 'We''re truly sorry, but something horrible has gone wrong when starting up CommandBox.', true );
	    	systemOutput( 'Here''s what we know:.', true );
	    	systemOutput( '', true );
	    	systemOutput( 'Message:', true );
	    	systemOutput( '#err.message#', true );
	    	systemOutput( '', true );
			if( structKeyExists( err, 'detail' ) ) {
	    		systemOutput( '#err.detail#', true );
			}
			if( structKeyExists( err, 'tagcontext' ) ){
				lines = arrayLen( err.tagcontext );
				if( lines != 0 ){
					systemOutput( 'Tag Context:', true );
					for( idx=1; idx <= lines; idx++) {
						tc = err.tagcontext[ idx ];
						if( len( tc.codeprinthtml ) ){
							if( idx > 1 ) {
	    						systemOutput( 'called from ' );
							}
	   						systemOutput( '#tc.template#: line #tc.line#', true );
						}
					}
				}
			}
			if( verboseErrors ) {
		    	systemOutput( '', true );
		    	systemOutput( '#err.stacktrace#', true );	
			} else {
		    	systemOutput( '', true );
				systemOutput( 'To enable full stack trace, run "config set verboseErrors=true"', true );
		    	systemOutput( '', true );
			}
	
	    	//writeDump(var=cfcatch, output="console");
	
			// ignore "sleep interrupted" exception if they hit Ctrl-C here
			try {
				// Give them a chance to read it
				sleep( 30000 );
			} catch( any e ) {}
		</cfscript>
	</cfcatch>
</cftry>
</cfsilent>
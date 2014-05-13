<cfsilent>
<!--- I bootstrap CommandBox up, create the shell and get it running.
I am a CFC because the Railo CLI seems to need a .cfm file to call --->
<!---This file will stay running the entire time the shell is open --->
<cfsetting requesttimeout="999999" />
<!---Display this banner to users--->
<cfsavecontent variable="banner">Welcome to CommandBox!
Type "help" for help, or "help [command]" to be more specific.
  _____                                          _ ____
 / ____|                                        | |  _ \
| |     ___  _ __ ___  _ __ ___   __ _ _ __   __| | |_) | _____  __
| |    / _ \| '_ ` _ \| '_ ` _ \ / _` | '_ \ / _` |  _ < / _ \ \/ /
| |___| (_) | | | | | | | | | | | (_| | | | | (_| | |_) | (_) >  <
 \_____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|\__,_|____/ \___/_/\_\ v@@version@@
</cfsavecontent>
<cfscript>
	system = createObject("java","java.lang.System");
	args = system.getProperty("cfml.cli.arguments");
	try {
		if(!isNull(args) && trim(args) != "") {
    		outputStream = createObject("java","java.io.ByteArrayOutputStream").init();
    		bain = createObject("java","java.io.ByteArrayInputStream").init("#args##chr(10)#".getBytes());
        	printWriter = createObject("java","java.io.PrintWriter").init(outputStream);
			shell = new commandbox.system.Shell(bain,printWriter);
			shell.callCommand(args);
			system.out.print(outputStream);
			system.out.flush();
		} else {
			// Create the shell
			shell = new commandbox.system.Shell();
			// Output the welcome banner
			banner = replace( banner, '@@version@@', shell.getVersion() );
			systemOutput( banner );

			// Running the "reload" command will enter this while loop once
			while( shell.run() ){
				SystemCacheClear( "all" );
				shell = javacast( "null", "" );
				shell = new commandbox.system.Shell();
			}
		}
	} catch ( any e ) {
		// Give nicer message to user
		printError( e );
		// Give them a chance to read it
		sleep( 30000 );
	}

	system = createObject( "java", "java.lang.System" );
    system.runFinalization();
    system.gc();

    function printError( required err ) {
    	var CR = chr( 13 );
    	systemOutput( 'BOOM GOES THE DYNAMITE!!', true );
    	systemOutput( 'We''re truly sorry, but something horrible has gone wrong when starting up CommandBox.', true );
    	systemOutput( 'Here''s what we know:.', true );
    	systemOutput( '', true );
    	systemOutput( '#err.message#', true );
    	systemOutput( '', true );
		if( structKeyExists( err, 'detail' ) ) {
    		systemOutput( '#err.detail#', true );
		}
    	systemOutput( '#err.stacktrace#', true );
    	return;
	}



</cfscript>
</cfsilent>

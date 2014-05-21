<!---
*********************************************************************************
 Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
 www.coldbox.org | www.ortussolutions.com
********************************************************************************
@author Brad Wood, Luis Majano, Denny Valliant

I bootstrap CommandBox up, create the shell and get it running.
I am a CFC because the Railo CLI seems to need a .cfm file to call
This file will stay running the entire time the shell is open

--->
<cfsilent>
<cfset variables.wireBox = application.wireBox>
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

	if(!isNull(args) && trim(args) != "") {
		//outputStream = createObject("java","java.io.ByteArrayOutputStream").init();
		//bain = createObject("java","java.io.ByteArrayInputStream").init("#args##chr(10)#".getBytes());
    	//printWriter = createObject("java","java.io.PrintWriter").init(outputStream);
		shell = WireBox.getInstance( 'Shell' );
		shell.callCommand(args);
		//system.out.print(outputStream);
		//system.out.flush();
	} else {
		// Create the shell
		shell = WireBox.getInstance( 'Shell' );
		// Output the welcome banner
		banner = replace( banner, '@@version@@', shell.getVersion() );
		systemOutput( banner );

		// Running the "reload" command will enter this while loop once
		while( shell.run() ){
			SystemCacheClear( "all" );
			shell = javacast( "null", "" );
			wirebox.clearSingletons();
			shell = WireBox.getInstance( 'Shell' );
		}
	}

	system = createObject( "java", "java.lang.System" );
    system.runFinalization();
    system.gc();



</cfscript>
</cfsilent>

<!-----------------------------------------------------------------------
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Description :
This is the Default ColdBox LogBox Configuration for immediate operation 
of ColdBox once it loads.  Once the configuration file is read then the
LogBox instance is reconfigured with the user settings, if used at all.
----------------------------------------------------------------------->
<cfcomponent output="false" hint="The default ColdBox LogBox Configuration Data Object">
<cfscript>
	/**
	* Configure LogBox, that's it!
	*/
	function configure(){
		var system 	= createObject( "java", "java.lang.System" );
		
		logBox = {};
		
		// Define Appenders
		logBox.appenders = {
			fileAppender = { 
				class="wirebox.system.logging.appenders.AsyncRollingFileAppender",
				properties = {
					fileMaxArchives = 5, 
					filename = "commandbox", 
					filepath = system.getProperty( 'user.home' ) & "/.CommandBox/logs"
				}
			}
		};
		
		// Root Logger
		logBox.root = {
			levelmax="INFO",
			levelMin="FATAL",
			appenders="*"
		};
	}
</cfscript>
</cfcomponent>

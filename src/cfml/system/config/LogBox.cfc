/**
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Description :
This is the Default ColdBox LogBox Configuration for immediate operation
of ColdBox once it loads.  Once the configuration file is read then the
LogBox instance is reconfigured with the user settings, if used at all.
*/
component {

	function configure(){
		var system 	= createObject( "java", "java.lang.System" );
		var homeDir	= isNull(system.getProperty('cfml.cli.home')) ?
				system.getProperty('user.home') & "/.CommandBox/" : system.getProperty('cfml.cli.home');

		logBox = {};


		// Define Appenders
		logBox.appenders = {
			fileAppender = {
				class="wirebox.system.logging.appenders.AsyncRollingFileAppender",
				properties = {
					fileMaxArchives = 5,
					filename = "commandbox",
					filepath = homeDir & "/logs"
				}
			},
			ANSIConsoleAppender = {
				class="commandbox.system.util.ANSIConsoleAppender"
			}
		};

		// Root Logger
		logBox.root = {
			levelmax="INFO",
			levelMin="FATAL",
			appenders="fileAppender"
		};

		logBox.categories = {
			"console" = {appenders="ANSIConsoleAppender"}
		};

	}
}
/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* LogBox Configuration
*/
component {

	function configure(){
		var system 	= createObject( "java", "java.lang.System" );
		var homeDir	= isNull( system.getProperty('cfml.cli.home') ) ?
				system.getProperty( 'user.home' ) & "/.CommandBox/" : system.getProperty( 'cfml.cli.home' );

		logBox = {};


		// Define Appenders
		logBox.appenders = {
			fileAppender = {
				class="wirebox.system.logging.appenders.RollingFileAppender",
				properties = {
					fileMaxArchives = 5,
					filename = "commandbox",
					filepath = homeDir & "/logs"
				},
				async=true
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
			"console" = { appenders="ANSIConsoleAppender" }
		};

	}
}
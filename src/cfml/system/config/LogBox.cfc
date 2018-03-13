/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* LogBox Configuration
*/
component {

	function configure(){
		
		logBox = {};

		// Define Appenders
		logBox.appenders = {
			fileAppender = {
				class="wirebox.system.logging.appenders.RollingFileAppender",
				properties = {
					fileMaxArchives = 5,
					filename = "commandbox",
					filepath = expandpath( '/commandbox-home' ) & "/logs",
					autoExpand=false
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

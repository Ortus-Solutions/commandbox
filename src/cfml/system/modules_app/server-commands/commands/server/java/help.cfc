/**
*/
component excludeFromHelp=true {

	function run()  {

		print.line()
		.yellow( 'The ' ).boldYellow( 'server java' ).yellowLine( ' namespace contains commands that allow you to ' )
		.yellowLine( 'view, manage and configure the default versions of Java used to start your servers.' )
		.yellowLine( 'CommandBox can automatically fetch any OpenJDK build from https://adoptopenjdk.net/.' )
		.line()
		.line();

	}
}

/**
 * Start the embedded CFMLserver
 **/
component persistent="false" extends="cli.BaseCommand" aliases="start" excludeFromHelp=false {

	function run() {
		shell.callCommand( "cfdistro serverStart" );
	}



}
/**
 * run server
 **/
component persistent="false" extends="cli.BaseCommand" aliases="start" {

	function run() {
		shell.callCommand( "cfdistro serverStart" );
	}



}
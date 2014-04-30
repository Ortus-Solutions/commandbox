/**
 * stop server
 **/
component persistent="false" extends="cli.BaseCommand" aliases="stop" {

	function run() {
		shell.callCommand( "cfdistro serverStop" );
	}

}
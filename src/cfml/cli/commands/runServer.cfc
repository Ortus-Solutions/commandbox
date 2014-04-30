/**
 * run server
 **/
component persistent="false" extends="cli.BaseCommand" aliases="run" {

	function run() {
		var cfdistro = new cli.commands.cfdistro.cfdistro();
		cfdistro.serverStart();
	}



}
/**
 * stop server
 **/
component persistent="false" extends="cli.BaseCommand" aliases="stop" {

	function run() {
		var cfdistro = new cli.commands.cfdistro.cfdistro();
		cfdistro.serverStop();
	}

}
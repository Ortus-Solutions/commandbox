/**
 * returns shell version
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	function run()  {
		return shell.version();
	}

}
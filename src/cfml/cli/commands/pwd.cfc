/**
 * print working directory (current dir)
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	function run()  {
		return shell.pwd();
	}



}
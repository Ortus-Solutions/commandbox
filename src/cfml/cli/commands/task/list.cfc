/**
 * List all tasks
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  ) {
		print.line( "faux-list!" );
	}

}
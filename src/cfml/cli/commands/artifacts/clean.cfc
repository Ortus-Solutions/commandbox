/**
 * Clean out the artifacts cache
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  ) {
		print.line( "clean packages!" );
	}

}
/**
 * executes a cfml file
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	function run( file="" )  {
		return include(file);
	}



}
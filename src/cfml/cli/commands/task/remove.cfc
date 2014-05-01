/**
 * Remvoe a task
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=false {

	/** 
	 * @name.hint The Task name
	 **/
	function run( required String name ) {
		print.line( "faux-remove! Task:#name#" );
	}

}
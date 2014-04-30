/**
 * change directory
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	/**
	 * @directory.hint directory to CD to
	 **/
	function run( directory="" )  {
		return shell.cd( directory );
	}


}
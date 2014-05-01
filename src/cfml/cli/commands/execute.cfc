/**
 * Executes a CFML file.
 * 
 * execute myFile.cfm
 * 
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" {

	/**
	 * 
	 * @file.hint The file to execute.
	 * 
	 **/
	function run( file="" )  {
		return include(file);
	}



}
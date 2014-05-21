/**
 * Executes a CFML file.
 * 
 * execute myFile.cfm
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * 
	 * @file.hint The file to execute.
	 * 
	 **/
	function run( file="" )  {
		return include(file);
	}



}
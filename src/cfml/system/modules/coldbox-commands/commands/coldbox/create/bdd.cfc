/**
* Create a new BDD spec in an existing ColdBox-enabled application.  Run this command in the root
* of your app for it to find the correct folder.  By default, your new BDD spec will be created in /tests/specs but you can 
* override that with the directory param.
* .
* {code:bash}
* coldbox create bdd mySpec
* {code}
*  
**/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	/**
	* @name.hint Name of the BDD spec to create without the .cfc. For packages, specify name as 'myPackage/myBDDSpec'
	* @open.hint Open the file once it is created
	* @directory.hint The base directory to create your BDD spec in, defaults to 'tests/specs'
	**/
	function run( required name, boolean open=false, directory="tests/specs" ){
		// proxy to testbox
		runCommand( "testbox create bdd name=#arguments.name# directory=#arguments.directory# open=#arguments.open#" );
	}

}
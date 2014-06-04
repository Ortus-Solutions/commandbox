/**
* This will create a new xUnit Bundle in an existing ColdBox-enabled application.  Make sure you are running this command in the root
* of your app for it to find the correct folder.  By default, your new xUnit Bundle will be created in /tests/specs but you can 
* override that with the directory param.    
*  
**/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {
	
	/**
	* @name.hint Name of the xUnit Bundle to create without the .cfc. For packages, specify name as 'myPackage/MyServiceTest'
	* @open.hint Open the file once it is created
	* @directory.hint The base directory to create your BDD spec in, defaults to 'tests/specs'
	**/
	function run( required name, boolean open=false, directory="tests/specs" ){
		// proxy to testbox
		shell.callCommand( "testbox create unit name=#arguments.name# directory=#arguments.directory# open=#arguments.open#" );
	}

}
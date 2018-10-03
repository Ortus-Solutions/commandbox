/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the base task implementation.  An abstract class if you will.
*
*/
component accessors="true" extends='commandbox.system.BaseCommand' {

	// Tasks mostly just do everything commands do

	/**
	 * Run another task by DSL.
	 * @taskFile The name of the task to run.
 	 **/
	function task( required taskFile='task' ) {
		return getinstance( name='TaskDSL', initArguments={ taskFile : arguments.taskFile } )
			.inWorkingDirectory( getDirectoryFromPath( getCurrentTemplatePath() ) );
	}

	/**
	 * Loads a module into memory from disk.  Relative paths will be resolved
	 * based on the location of the task runner CFC.
	 * The module will be left in memory and will not be unloaded.
	 * If the module is already loaded in memory, nothing will happen.
	 * 
	 * @moduleDirectory Path to module folder. Ex: build/modules/myModule/
 	 **/
	function loadModule( required string moduleDirectory ) {
		
		// Expand path relative to the task CFC.
		moduleDirectory = resolvePath( moduleDirectory );
		
		// A little validation...
		if( !directoryExists( moduleDirectory ) ) {
			error( 'Cannot load module.  Path [#moduleDirectory#] doesn''t exist.' );
		}
		
		// Generate a CF mapping that points to the module's folder
		var relativeModulePath = fileSystemUtil.makePathRelative( moduleDirectory );
		
		// A dot delimited path that points to the folder containing the module
		var invocationPath = relativeModulePath
			.listChangeDelims( '.', '/\' )
			.listDeleteAt( relativeModulePath.listLen( '/\' ), '.' );
			
		// The name of the module
		var moduleName = relativeModulePath.listLast( '/\' );
		
		// Load it up!!
		wirebox.getInstance( 'moduleService' ).registerAndActivateModule( moduleName, invocationPath );
	}

	/**
	* This resolves an absolute or relative path using the rules of the operating system and CLI.
	* It doesn't follow CF mappings and will also always return a trailing slash if pointing to 
	* an existing directory.
	* 
	* Resolve the incoming path from the file system
	* @path.hint The directory to resolve
	* @basePath.hint An expanded base path to resolve the path against. Defaults to direcory that the task lives in.
	*/
	function resolvePath( required string path, basePath=getDirectoryFromPath( getCurrentTemplatePath() ) ) {
		return filesystemUtil.resolvepath( path, basePath );
	}
	
}

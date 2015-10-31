/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
* I am the CFLIb-ColdBox endpoint.  I get packages from CFblib.org based on their slug
* and store them as a ColdBox module, wrapping the UDF in a CFC so it can be injected.
*/
component accessors="true" implements="IEndpoint" extends="commandbox.system.endpoints.CFLib" singleton {
		
	// Properties
	property name="namePrefixes" type="string";
	
	function init() {
		setNamePrefixes( 'CFLib-ColdBox' );
		return this;
	}
		
	public string function resolvePackage( required string package, boolean verbose=false ) {
		// Retrieve the UDF in a single .cfm file
		var tempFolder = super.resolvePackage( argumentCollection = arguments );
		var tempFile = tempFolder & '/' & package & '.cfm'; 
		
		// Turn this baby into a module!
		createModuleConfig( tempFolder );
		createModel( tempFolder, tempFile );
		createBoxJSON( tempFolder, arguments.package );
		
		// Return the new and improved folder
		return tempFolder;
	}
	
	private function createModuleConfig( required string tempFolder ) {
		var fileContents = 'component {
			this.modelNamespace="cflib"
			function configure() {}
			}';
		fileWrite( arguments.tempFolder & '/ModuleConfig.cfc', fileContents );
	}
	
	private function createModel( required string tempFolder, required string tempFile ) {
		var modelsDir = arguments.tempFolder & '/models';
		var funcContent = fileRead( arguments.tempFile );
		directoryCreate( modelsDir, true, true );
		
		var modelContent = '<c' & 'fcomponent>#chr(13)##chr(10)#' & funcContent & '#chr(13)##chr(10)#</c' & 'fcomponent>';
		fileWrite( modelsDir & '/' & replaceNoCase( listLast( arguments.tempFile, '/' ), '.cfm', '.cfc' ), modelContent );
		fileDelete( arguments.tempFile );
	}
	
	private function createBoxJSON( required string tempFolder, required string package ) {
		var fileContents = '{
			"name"="#arguments.package#",
			"slug"="#arguments.package#",
			"version"="1.0.0",
			"type"="modules",
			"homepage"="http://www.cflib.org/udf/#arguments.package#",
			"documentation"="http://www.cflib.org/udf/#arguments.package#"
		}';
		fileWrite( arguments.tempFolder & '/box.json', fileContents );		
	}

}
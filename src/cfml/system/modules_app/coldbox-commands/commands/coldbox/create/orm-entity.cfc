/**
* Create a new CFML ORM entity.  You can pass in extra attributes like making it an enhanced ColdBox ORM Active Entity, or generating
* primary keys and properties.
* .
* You can pass a primary key value or use the default of 'id'. You can then pass also an optional primary key table name and generator.
* The default generator used is 'native'
* .
* To generate properties you will pass a list of property names to the 'properties' argument.  You can also add
* ORM types to the properties by separating them with a colon.  For example:
* {code:bash}
* properties=name,createDate:timestamp,age:numeric
* {code}
* .
* Make sure you are running this command in the root of your app for it to find the correct folder.
* .
* {code:bash}
* // Basic
* coldbox create orm-entity User --open
*
* // Active Entity
* coldbox create orm-entity User --open --activeEntity
*
* // With Some Specifics
* coldbox create orm-entity entityName=User table=users primaryKey=userID generator=uuid
*
* // With some properties
* coldbox create orm-entity entityName=User properties=firstname,lastname,email,createDate:timestamp,updatedate:timestamp,age:numeric
* {code}
*
 **/
component {

	/**
	* @entityName The name of the entity without .cfc
	* @table The name of the mapped table or empty to use the same name as the entity
	* @directory The base directory to create your model in and creates the directory if it does not exist.
	* @activeEntity Will this be a ColdBox ORM Active entity or a Normal CFML entity. Defaults to false.
	* @primaryKey Enter the name of the primary key, defaults to 'id'
	* @primaryKeyColumn Enter the name of the primary key column. Leave empty if same as the primaryKey value
	* @generator Enter the ORM key generator to use, defaults to 'native'
	* @generator.options increment,identity,sequence,native,assigned,foreign,seqhilo,uuid,guid,select,sequence-identiy
	* @properties Enter a list of properties to generate. You can add the ORM type via colon separator, default type is string. Ex: firstName,age:numeric,createdate:timestamp
	* @tests Generate the unit test BDD component
	* @testsDirectory Your unit tests directory. Only used if tests is true
	* @script Generate as script or not, defaults to true
	* @open Open the file(s) once generated
	**/
	function run(
		required entityName,
		table="",
		directory="models",
		boolean activeEntity=false,
		primaryKey="id",
		primaryKeyColumn="",
		generator="native",
		properties="",
		boolean tests=true,
		testsDirectory='tests/specs/unit',
		boolean script=true,
		boolean open=false
	) {
		// non-canonical path
		var nonCanonicalDirectory 	= arguments.directory;
		// This will make each directory canonical and absolute
		arguments.directory 		= resolvePath( arguments.directory );
		arguments.testsDirectory 	= resolvePath( arguments.testsDirectory );

		// Validate directory
		if( !directoryExists( arguments.directory ) ) {
			directoryCreate( arguments.directory );
		}

		// script
		var scriptPrefix = "";
		if( arguments.script ){ scriptPrefix = "Script"; }

		// Argument defaults
		if( !len( arguments.table ) ){ arguments.table = arguments.entityName; }
		if( !len( arguments.primaryKeyColumn ) ){ arguments.primaryKeyColumn = arguments.primaryKey; }

		// Read in Template
		var modelContent 	 		= fileRead( '/coldbox-commands/templates/orm/Entity#scriptPrefix#.txt' );
		var modelTestContent 		= fileRead( '/coldbox-commands/templates/testing/ORMEntityBDDContent#scriptPrefix#.txt' );

		// Basic replacements
		modelContent 	= replaceNoCase( modelContent, '|entityName|', arguments.entityName, 'all' );
		modelContent 	= replaceNoCase( modelContent, '|table|', arguments.table, 'all' );
		modelContent 	= replaceNoCase( modelContent, "|primaryKey|", arguments.primaryKey,"all" );
		modelContent 	= replaceNoCase( modelContent, "|primaryKeyColumn|", arguments.primaryKeyColumn,"all" );
		modelContent 	= replaceNoCase( modelContent, "|generator|", arguments.generator,"all" );

		// Active Entity?
		if( arguments.activeEntity ){
			modelContent = replaceNoCase( modelContent, "|activeEntity|",' extends="cborm.models.ActiveEntity"',"all" );
			modelContent = replaceNoCase( modelContent, "|activeEntityInit|",'super.init( useQueryCaching="false" );', "all" );
		} else {
			modelContent = replaceNoCase( modelContent, "|activeEntity|", "", "all" );
			modelContent = replaceNoCase( modelContent, "|activeEntityInit|", "", "all" );
		}

		// Test Content Replacement
		modelTestContent = replaceNoCase( modelTestContent, '|modelName|', "#nonCanonicalDirectory#.#arguments.entityName#", 'all' );
		modelTestContent = replaceNoCase( modelTestContent, '|TestCases|', "", 'all');

		// Properties
		var properties 	= listToArray( arguments.properties );
		var buffer 		= createObject( "java", "java.lang.StringBuffer" ).init();
		for( var thisProperty in properties ){
			var propName = getToken( trim( thisProperty ), 1, ":");
			var propType = getToken( trim( thisProperty ), 2, ":");
			if( NOT len( propType ) ){ propType = "string"; }

			if( arguments.script ){
				buffer.append( 'property name="#propName#" ormtype="#propType#";#chr(13) & chr(9)#' );
			} else {
				buffer.append( chr( 60 ) & 'cfproperty name="#propName#" ormtype="#propType#">#chr(13) & chr(9)#' );
			}
		}
		modelContent = replaceNoCase( modelContent, "|properties|", buffer.toString() );

		// Write out the model
		var modelPath = '#arguments.directory#/#arguments.entityName#.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( modelPath ), true, true );

		// Confirm it
		if( fileExists( modelPath ) && !confirm( "The file '#getFileFromPath( modelPath )#' already exists, overwrite it (y/n)?" ) ){
			print.redLine( "Exiting..." );
			return;
		}

		file action='write' file='#modelPath#' mode ='777' output='#modelContent#';
		print.greenLine( 'Created #modelPath#' );

		if( arguments.tests ) {
			var testPath = '#arguments.TestsDirectory#/#arguments.entityName#Test.cfc';
			// Create dir if it doesn't exist
			directorycreate( getDirectoryFromPath( testPath ), true, true );
			// Create the tests
			file action='write' file='#testPath#' mode ='777' output='#modelTestContent#';
			// open file
			if( arguments.open ){ openPath( testPath ); }
			print.greenLine( 'Created #testPath#' );
		}

		// Open file?
		if( arguments.open ){ openPath( modelPath ); }
	}

}

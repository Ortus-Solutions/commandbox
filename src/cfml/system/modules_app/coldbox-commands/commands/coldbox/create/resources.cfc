/**
 * Generate resourceful routing by generating a handler, model, services and even modularizing it.
 * .
 * Make sure you are running this command in the root of your app for it to find the correct folder.
 * .
 * The following would create a `photos` handler with the following actions: 
 * - `/photos` : `GET` -> `photos.index` Display a list of photos
 * - `/photos/new` : `GET` -> `photos.new` Returns an HTML form for creating a new photo
 * - `/photos` : `POST` -> `photos.create` Create a new photo
 * - `/photos/:id` : `GET` -> `photos.show` Display a specific photo
 * - `/photos/:id/edit` : `GET` -> `photos.edit` Return an HTML form for editing a photo
 * - `/photos/:id` : `POST/PUT/PATCH` -> `photos.update` Update a specific photo
 * - `/photos/:id` : `DELETE` -> `photos.delete` Delete a specific photo
 * {code:bash}
 * // Basic
 * coldbox create resources photos
 * // Many resources
 * coldbox create resources photos,users,categories
 * // Custom Handler
 * coldbox create resources photos myPhoto
 * coldbox create resources resource=photos handler=myPhoto
 * // ORM Enabled 
 * coldbox create resources resource=photos singularName=Photo --persistent
 * {code}
 *
 */
component {

	// STATIC Actions we use in the resources
	variables.ACTIONS = [ 
		"index",
		"new",
		"create",
		"show ",
		"edit",
		"update",
		"delete"
	];

	/**
	 * @resource The name of a single resource or a list of resources to generate
	 * @handler The handler for the resource. Defaults to the resource name, only works when using one resource
	 * @singularName The singular name of the resource, else we use the resource name
	 * @parameterName The name of the id/parameter for the resource. Defaults to `id`.
	 * @module If passed, the module these resources will be created in.
	 * @appMapping.hint The root location of the application in the web root: ex: /MyApp or / if in the root
	 * 
	 * @model The name of the model to generate that models the resource
	 * @persistent If true, then the model will be created as an ORM entity
	 * @table The table name of the entity
	 * @activeEntity Will this be a ColdBox ORM Active entity or a Normal CFML entity. Defaults to false.
	 * @primaryKey Enter the name of the primary key, defaults to 'id'
	 * @primaryKeyColumn Enter the name of the primary key column. Leave empty if same as the primaryKey value
	 * @generator Enter the ORM key generator to use, defaults to 'native'
	 * @generator.options increment,identity,sequence,native,assigned,foreign,seqhilo,uuid,guid,select,sequence-identiy
	 * @properties Enter a list of properties to generate. You can add the ORM type via colon separator, default type is string. Ex: firstName,age:numeric,createdate:timestamp
	 * 
	 * @handlersDirectory The location of the handlers. Defaults to 'handlers'
	 * @viewsDirectory The location of the views. Defaults to 'views'
	 * @tests Generate the integration and unit tests for this generation
	 * @specsDirectory Your specs directory. Only used if tests is true
	 */
	function run(
		required resource,
		handler=arguments.resource,
		singularName=arguments.resource,
		parameterName="id",
		module="",
		appMapping="/",
		
		model=arguments.resource,
		persistent=false,
		table="",
		boolean activeEntity=false,
		primaryKey="id",
		primaryKeyColumn="",
		generator="native",
		properties="",
		
		handlersDirectory="handlers",
		viewsDirectory="views",
		boolean tests=true,
		specsDirectory='tests/specs'
	) {

		// This will make each directory canonical and absolute
		arguments.handlersDirectory	= fileSystemUtil.resolvePath( arguments.handlersDirectory );
		arguments.viewsDirectory 	= fileSystemUtil.resolvePath( arguments.viewsDirectory );
		arguments.specsDirectory 	= fileSystemUtil.resolvePath( arguments.specsDirectory );

		/********************** GENERATE HANDLER ************************/

		print.greenBoldLine( "Generating #arguments.resource# resources..." );

		// Read in Template
		var hContent = fileRead( '/coldbox-commands/templates/resources/HandlerContent.txt' );
		// Token replacement
		hContent = replacenocase( hContent, "|resource|",       arguments.resource,         "all" );
		hContent = replacenocase( hContent, "|singularName|",   arguments.singularName,     "all" );
		hContent = replacenocase( hContent, "|parameterName|",  arguments.parameterName,    "all" );

		// Write Out Handler
		var hpath = '#arguments.handlersDirectory##arguments.handler#.cfc';
		// Create dir if it doesn't exist
		directorycreate( getDirectoryFromPath( hpath ), true, true );

		// Confirm it
		if( fileExists( hpath ) && !confirm( "The file '#getFileFromPath( hpath )#' already exists, overwrite it (y/n)?" ) ){
			print.redLine( "Exiting..." );
			return;
		}
		file action='write' file='#hpath#' mode ='777' output='#hContent#';
		print.blueLine( '--> Generated (#arguments.resource#) Handler: #hPath#' );

		//********************** generate views ************************************//

		// Create Views Path
		directorycreate( arguments.viewsDirectory & "/#arguments.resource#", true, true );
		var views = [ "new", "edit", "show" ];
		for( var thisView in views ){
			var vContent = fileRead( '/coldbox-commands/templates/resources/#thisView#.txt' );
			vContent = replacenocase( vContent, "|resource|", arguments.resource, "all" );
			vContent = replacenocase( vContent, "|singularName|", arguments.singularName, "all" );
			fileWrite( arguments.viewsDirectory & "/#arguments.resource#/#thisView#.cfm", vContent );
			print.blueLine( '--> Generated (#thisView#) View: ' & arguments.viewsDirectory & "#arguments.resource#/#thisView#.cfm" );
		}

		//********************** generate test cases ************************************//

		print.blueLine( '--> Generating integration tests...' );
		command( "coldbox create integration-test" )
			.params(
				handler    = arguments.handler,
				actions    = variables.ACTIONS.toList(),
				appMapping = arguments.appMapping
			)
			.run();

		//********************** generate model ************************************//

		// Generate an ORM Entity
		if( arguments.persistent ){
			print.blueLine( '--> Generating ORM resource model (#arguments.singularName#)' );
			command( "coldbox create orm-entity" )
				.params(
					entityName  		= ucFirst( arguments.singularName ),
					table 				= arguments.table,
					activeEntity		= arguments.activeEntity,
					primaryKey 			= arguments.primaryKey,
					primaryKeyColumn 	= arguments.primaryKeyColumn,
					generator 			= arguments.generator,
					properties 			= arguments.properties
				)
				.run();
			
			print.blueLine( '--> Generating ORM Virtual Service (#arguments.singularName#)' );
			command( "coldbox create orm-virtual-service" )
				.params(
					entityName  = arguments.singularName
				)
				.run();

		} else {
			print.blueLine( '--> Generating resource model (#arguments.singularName#)' );
			// Generate model
			command( "coldbox create model" )
				.params(
					name        = ucFirst( arguments.singularName ),
					description = "I model a #arguments.singularName#",
					properties  = arguments.properties
				)
				.run();

			// Generate Service
			print.blueLine( '--> Generating resource service (#arguments.resource#Service)' );
			command( "coldbox create model" )
				.params(
					name        = ucFirst( arguments.resource ) & "Service",
					persistence = "singleton",
					description = "I manage #arguments.singularName#",
					methods 	= "save,delete,list,get"
				)
				.run();
		}

		//********************** generate resources ************************************//
		
		print
			.line()
			.greenBoldLine( "Generation completed, please add the following to your routes.cfm:" )
				
		if( arguments.resource == arguments.handler ){
			if( arguments.parameterName != "id" ){
				print.greenLine( 'resources( resource="#arguments.resource#" );' );			
			} else {
				print.greenLine( 'resources( resource="#arguments.resource#", parameterName="#arguments.parameterName#" );' );			
			}
		} else {
			if( arguments.parameterName != "id" ){
				print.greenLine( 'resources( resource="#arguments.resource#", handler="#arguments.handler#" );' );			
			} else {
				print.greenLine( 'resources( resource="#arguments.resource#", handler="#arguments.handler#", parameterName="#arguments.parameterName#" );' );			
			}
		}
		
	}

	
}

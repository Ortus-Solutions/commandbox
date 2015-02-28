/**
* Manage Users
* It will be your responsibility to fine tune this template, add validations, try/catch blocks, logging, etc.
*/
component{
	
	// DI Virtual Entity Service
	property name="ormService" inject="entityService:User";
	
	// HTTP Method Security
	this.allowedMethods = {
		index = "GET", new = "GET", edit = "GET", delete = "POST,DELETE", save = "POST,PUT"
	};
	
	/**
	* preHandler()
	*/
	function preHandler( event, rc, prc ){
		event.paramValue( "format", "html" );
	}
		
	/**
	* Listing
	*/
	function index( event, rc, prc ){
		// Get all Users
		prc.Users = ormService.getAll();
		// Multi-format rendering
		event.renderData( data=prc.Users, formats="xml,json,html,pdf" );
	}	
	
	/**
	* New Form
	*/
	function new( event, rc, prc ){
		// get new User
		prc.User = ormService.new();
		
		event.setView( "Users/new" );
	}	

	/**
	* Edit Form
	*/
	function edit( event, rc, prc ){
		// get persisted User
		prc.User = ormService.get( rc.user_id );
		
		event.setView( "Users/edit" );
	}	
	
	/**
	* View User mostly used for RESTful services only.
	*/
	function show( event, rc, prc ){
		// Default rendering.
		event.paramValue( "format", "json" );
		// Get requested entity by id
		prc.User = ormService.get( rc.user_id );
		// Multi-format rendering
		event.renderData( data=prc.User, formats="xml,json" );
	}

	/**
	* Save and Update
	*/
	function save( event, rc, prc ){
		// get User to persist or update and populate it with incoming form
		prc.User = populateModel( model=ormService.get( rc.user_id ), exclude="user_id", composeRelationships=true );
		
		// Do your validations here
		
		// Save it
		ormService.save( prc.User );
		
		// RESTful Handler
		switch(rc.format){
			// xml,json,jsont are by default.  Add your own or remove
			case "xml" : case "json" : case "jsont" :{
				event.renderData( data=prc.User, type=rc.format, location="/Users/show/#prc.User.getuser_id()#" );
				break;
			}
			// HTML
			default:{
				// Show a nice notice
				flash.put( "notice", { message="User Created", type="success" } );
				// Redirect to listing
				setNextEvent( 'Users' );
			}
		}
	}	

	/**
	* Delete
	*/
	function delete( event, rc, prc ){
		// Delete record by ID
		var removed = ormService.delete( ormService.get( rc.user_id ) );
		
		// RESTful Handler
		switch( rc.format ){
			// xml,json,jsont are by default.  Add your own or remove
			case "xml" : case "json" : case "jsont" :{
				var restData = { "deleted" = removed };
				event.renderData( data=restData, type=rc.format );
				break;
			}
			// HTML
			default:{
				// Show a nice notice
				flash.put( "notice", { message="User Poofed!", type="success" } );
				// Redirect to listing
				setNextEvent( 'Users' );
			}
		}
	}	
	
}

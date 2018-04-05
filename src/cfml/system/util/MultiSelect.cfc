/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* Sweet ASCII input control
*/
component accessors=true {

	// The question to present to the user
	property name='question' type="string";
	// The options to present to the user
	property name='options' type="array";
	// Can more than one option be selected at a time
	property name='multiple' type="boolean";
	// Can the input be submitted without anything selected?
	property name='required' type="boolean";

	// DI
	property name='shell' inject='shell';
	property name='printBuffer' inject='printBuffer';
	property name='print' inject='print';

	function init() {
		// Static reference to the class so we can create instances later
		aStr = createObject( 'java', 'org.jline.utils.AttributedString' );
		// Currently highlighted option on the screen
		activeOption = 1;
		
		// Default these since they're optional
		multiple=false;		
		required=false;
		question='';
		
		return this;
	}
	
	function onDIComplete() {
		terminal = shell.getReader().getTerminal();
		display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );
	}

	/**
	* Call this method after all options and settings have been placed. This method will block while the user interacts
	* with the input control and will return a string containing the value of the selected option.  If "multiple" is 
	* enabled, this method will return an array of selected values.
	*/
	function ask(){

		if( isNull( getOptions() ) ) {
			throw( 'No options defined. Provde a list or array of structs (display,value,selected)' );
		}
		
		printBuffer
			.text( getQuestion() )
			.toConsole();
		
		try {
			draw();
			
			while( ( var key = shell.waitForKey() ) != chr( 13 ) || !checkRequired() ) {
				
				if( isUp( key ) ) {
					activeOption = max( 1, activeOption-1 );
				} else if ( isDown( key ) ) {
					activeOption = min( getOptions().len(), activeOption+1 );
				} else if ( isSelect( key ) ) {
					doSelect( activeOption );					
				// Access key?
				} else {
					var i = 0;
					for( var o in getOptions() ) {
						i++;
						if( key == o.accessKey ) {
							activeOption = i;
							doSelect( activeOption );
							break;
						}
					}
				}
				
				draw();
				
			}
		} finally {
		
			// Wipe out screen
			display.update(
				getOptions()
					.map( function( o ) {
						return aStr.init( '' );
						} )
				.prepend( aStr.init( '' ) )
				.prepend( aStr.init( '' ) )
				.append( aStr.init( ' ' ) ),
				getQuestion().len()
			);
			
		}
		
		// if in multiple mode
		if( multiple ) {
			
			// Print out comma delimited list of selected option display names
			printBuffer
				.line( 
					getOptions().reduce( function( prev='', o ) {
						if( o.selected ) {
							prev = prev.listAppend( ' ' & o.display );
						}
						return prev;
					} )
					.trim()
				)
				.toConsole();
			
			// Return an array of selected option values
			return getOptions().reduce( function( prev=[], o ) {
				if( o.selected ) {
					prev.append( o.value );
				}
				return prev;
			} );
			
		// In single mode
		} else { 
			
			// Print out the first found selected option display name
			printBuffer
				.line(
					getOptions().reduce( function( prev='', o ) {
						if( o.selected ) {
							return o.display;
						}
						return prev;
					} )
				)
				.toConsole();
				
			// Return the first found selected option value
			return getOptions().reduce( function( prev='', o ) {
				if( o.selected ) {
					return o.value;
				}
				return prev;
			} );
			
		}
	}
	
	function setOptions( options ) {
		var opts = [];
		
		// Simple list of options
		if( isSimpleValue( options ) ) {
			
			options.listEach( function( i ) {
				opts.append( {
					display : i,
					value : i,
					selected : false,
					accessKey : i.left( 1 )
				} );
			} );
			
		} else if( isArray( options ) ) {
			
			options.each( function( i ) {
				
				if( !isStruct( i ) ) {
					throw( 'Option must be array of structs' );
				}
				
				if( isnull( i.value ) && isnull( i.display ) ) {
					throw( 'Option struct must have either a "value" key or "display" key. #serializeJSON( i )#' );
				}
				
				if( !isBoolean( i.selected ?: false ) ) {
					throw( 'Must pass boolean for "selected" key. Received: #serializeJSON( i.selected )#' );
				}
				
				opts.append( {
					display : i.display ?: i.value,
					value : i.value?: i.display,
					selected : i.selected ?: false,
					accessKey : i.accessKey ?: ( i.display ?: i.value ).left( 1 )
				} );
			} );
			
		} else {
			throw( 'Invalid type of options. Requires string or array of structs (display,value,selected).' );
		}
		
		variables.options = opts;
		return this;
	}

	private function draw() {
		display.update(
				generateRows(),
				( ( terminal.getWidth()+1) * ( activeOption+1 ) ) + 3
			);
	}
	
	private function generateRows() {
		var i = 0;
		return getOptions()
			.map( function( o ) {
				var optionFormatting = ( activeOption == ++i ? 'green' : '' );
				return aStr.fromAnsi(
					print.text( 
						'  [' & ( o .selected ? 'X' : ' ' ) & '] ' & reReplaceNoCase( o.display, '(#o.accessKey#)', print.bold( '\1' ) & print.text( '', optionFormatting, true ), 'once' ),
						optionFormatting
					)
				 );				 
			} )
			.prepend( aStr.init( '' ) )
			.prepend( aStr.init( '' ) )
			.append( aStr.init( ' ' ) );
	}

	function checkRequired() {
		if( !required ) {
			return true;
		}
		for( var o in getOptions() ) {
			if( o.selected ) {
				return true;
			}
		}
		return false;
	}
	
	
	function doSelect( optionNum ) {
		var i = 0;
		getOptions().each( function( o ) {
			i++
			if( i == activeOption ) {
				o.selected = !o.selected;
			} else if( !multiple ) {
				o.selected = false;
			}
		} );
	}

	private function isUp( key ) { 
		return ( key == 'key_up' || key == 'back_tab' );
	}
		
	private function isDown( key ) {
		return ( key == 'key_down' || key == chr( 9 ) );
	}
		
	private function isSelect( key ) {
		return ( key == ' ' || key == 'x' );
	}
}

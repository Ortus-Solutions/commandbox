/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*
* Sweet ASCII form control
*/
component accessors=true {

	property name='question' type="string";
	property name='options' type="array";
	property name='multiple' type="boolean";
	property name='required' type="boolean";

	// DI
	property name='shell' inject='shell';
	property name='printBuffer' inject='printBuffer';
	property name='print' inject='print';

	function init() {
		aStr = createObject( 'java', 'org.jline.utils.AttributedString' );
		selectedOption = 1;
		multiple=false;
		required=false;
		return this;
	}
	
	function onDIComplete() {
		terminal = shell.getReader().getTerminal();
		display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );
	}

	function ask(){

		if( isNull( getOptions() ) ) {
			throw( 'No options defined. Provde a list or array of structs (display,value,selected)' );
		}
		
		printBuffer
			.line( getQuestion() )
			.line( '' )
			.toConsole();
		
		try {
			draw();
			
			while( ( var key = shell.waitForKey() ) != chr( 13 ) || !checkRequired() ) {
				
				if( isUp( key ) ) {
					selectedOption = max( 1, selectedOption-1 );
				} else if ( isDown( key ) ) {
					selectedOption = min( getOptions().len(), selectedOption+1 );
				} else if ( isSelect( key ) ) {
					var i = 0;
					getOptions().each( function( o ) {
						i++
						if( i == selectedOption ) {
							o.selected = !o.selected;
						} else if( !multiple ) {
							o.selected = false;
						}
					} );
					
				} else {
					// systemoutput( key, 1 );
					// systemoutput( asc( key ), 1 );
				}
				
				draw();
				
			}
		} finally {
		
			// Wipe out screen
			display.update(
				getOptions()
					.map( function( o ) {
						return aStr.init( '' );
					} ),
				0
			);
		
		}
		
		if( multiple ) {
			return getOptions().reduce( function( prev=[], o ) {
				if( o.selected ) {
					prev.append( o.value );
				}
				return prev;
			} );
		} else {
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
					selected : false
				} );
			} );
			
		} else if( isArray( options ) ) {
			
			options.each( function( i ) {
				
				if( !isStruct( i ) ) {
					throw( 'Option must be array of structs' );
				}
				
				if( isnull( i.value ) ) {
					throw( 'Option is missing "value" key in struct. #serializeJSON( i )#' );
				}
				
				if( !isBoolean( i.selected ?: false ) ) {
					throw( 'Must pass boolean for "selected" key. Received: #serializeJSON( i.selected )#' );
				}
				
				opts.append( {
					display : i.display ?: i.value,
					value : i.value,
					selected : i.selected ?: false
				} );
			} );
			
		} else {
			throw( 'Invalid type of options. Requires string or array of structs (display,value,selected).' );
		}
		
		variables.options = opts;
		return this;
	}

	function draw() {
		display.update(
				generateRows(),
				( ( terminal.getWidth()+1) * ( selectedOption-1 ) ) + 3
			);
	}
	
	function generateRows() {
		var i = 0;
		return getOptions()
			.map( function( o ) {
				return aStr.fromAnsi(
					print.text( 
						'  [' & ( o .selected ? 'X' : ' ' ) & '] ' & o.display,
						( selectedOption == ++i ? 'boldBlue' : '' )
					)
				 );
			} );
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

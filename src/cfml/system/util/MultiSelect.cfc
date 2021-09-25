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
	property name='thisQuestion' type="string";
	// The options to present to the user
	property name='theOptions' type="array";
	// Can more than one option be selected at a time
	property name='isMultiple' type="boolean";
	// Can the input be submitted without anything selected?
	property name='isRequired' type="boolean";
	// Is this control active?
	property name='active' type="boolean";

	// DI
	property name='shell'			inject='shell';
	property name='printBuffer'		inject='printBuffer';
	property name='print'			inject='print';
	property name='job'				inject='provider:InteractiveJob';
	property name='ConsolePainter'	inject='provider:ConsolePainter';

	function init( string question='' ) {
		// Static reference to the class so we can create instances later
		aStr = createObject( 'java', 'org.jline.utils.AttributedString' );
		// Currently highlighted option on the screen
		activeOption = 1;

		// Default these since they're optional
		isMultiple=false;
		isRequired=false;
		thisQuestion=arguments.question;

		return this;
	}

	function onDIComplete() {
		terminal = shell.getReader().getTerminal();
		display = createObject( 'java', 'org.jline.utils.Display' ).init( terminal, false );
		display.resize( terminal.getHeight(), terminal.getWidth() );
	}

	function required( boolean required=true ) {
		setIsRequired( arguments.required );
		return this;
	}

	function getRequired() {
		return variables.IsRequired;
	}

	function setRequired( boolean required=true ) {
		variables.IsRequired = arguments.required;
		return this;
	}

	function multiple( boolean multiple=true ) {
		setIsMultiple( arguments.multiple );
		return this;
	}

	function getMultiple() {
		return variables.isMultiple;
	}

	function setMultiple( boolean multiple=true ) {
		variables.isMultiple = arguments.multiple;
		return this;
	}

	function question( required string question ) {
		setQuestion( arguments.question );
		return this;
	}

	function getQuestion() {
		return variables.thisQuestion;
	}

	function setQuestion( required string question ) {
		variables.thisQuestion = arguments.question;
		return this;
	}

	function options( required any options ) {
		setOptions( arguments.options );
		return this;
	}

	function getOptions() {
		return variables.thisOptions;
	}

	/**
	* Call this method after all options and settings have been placed. This method will block while the user interacts
	* with the input control and will return a string containing the value of the selected option.  If "multiple" is
	* enabled, this method will return an array of selected values.
	*/
	function ask(){

		if( isNull( getOptions() ) ) {
			throw( 'No options defined. Provide a list or array of structs (display,value,selected)' );
		}

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

			setActive( false );
			ConsolePainter.setMultiSelect( nullValue() );
			ConsolePainter.stop();

		}

		// if in multiple mode
		if( isMultiple ) {

			// Print out comma delimited list of selected option display names
			var response = getOptions()
				.reduce( function( prev='', o ) {
					if( o.selected ) {
						prev = prev.listAppend( ' ' & o.display );
					}
					return prev;
				} )
				.trim();

			if( job.getActive() ) {
				job.addLog( getQuestion() & ': ' & response );
			} else {
				printBuffer
					.line()
					.text( getQuestion() )
					.line( response )
					.toConsole();
			}


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
			var response = getOptions()
				.reduce( function( prev='', o ) {
				if( o.selected ) {
					return o.display;
				}
				return prev;
			} );

			if( job.getActive() ) {
				job.addLog( getQuestion() & ': ' & response );
			} else {
				printBuffer
					.line()
					.text( getQuestion() )
					.line( response )
					.toConsole();
			}

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

				if( isSimpleValue( i ) ) {

					opts.append( {
						display : i,
						value : i,
						selected : false,
						accessKey : i.left( 1 )
					} );

				} else {

					if( !isStruct( i ) ) {
						throw( 'Option must be array of structs or array of strings' );
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

				}
			} );

		} else {
			throw( 'Invalid type of options. Requires string or array of structs (display,value,selected).' );
		}

		variables.thisOptions = opts;
		return this;
	}

	private function draw() {
		setActive( true );
		ConsolePainter.setMultiSelect( this );
		ConsolePainter.start();
	}

	function getCursorPosition() {
		return {
			'row' : activeOption+2,
			'col' : 3
		};
	}

	function getLines() {
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
			.prepend( aStr.init( getQuestion() ) )
			.prepend( aStr.init( '' ) )
			.prepend( aStr.init( '' ) )
			.append( aStr.init( ' ' ) )
			.append( aStr.fromAnsi( print.yellow( '      Use <spacebar> to toggle selections, <enter> to submit.' ) ) )
			.append( aStr.init( ' ' ) );
	}

	function checkRequired() {
		if( !isRequired ) {
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
			} else if( !isMultiple ) {
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

Pretty print JSON objects witbh line breaks and indentation to make it more human readable.  
If you have an app that writes JSON files that humans need to easily be able to read, run the JSON through this library first.  It doesn't modify the data at all-- only the whitespace.

## Installation

```
CommandBox> install JSONPrettyPrint
```

## Usage
	
```
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( '{ "foo" : "bar" }' );
```

Or pass a complex CFML object and it will serialize for you.
	
```
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( { foo : 'bar' } );
```

The `JSONPrettyPrint` is a threadsafe singleton and suitable for injection.  Inject the library like so:

```
component {
  property name='JSONPrettyPrint' inject;
  
  function writeJSON( required JSON, required path ) {
  	fileWrite( path, JSONPrettyPrint.formatJSON( JSON ) );
  }
}
```
[![Build Status](https://travis-ci.org/Ortus-Solutions/JSONPrettyPrint.svg?branch=master)](https://travis-ci.org/Ortus-Solutions/JSONPrettyPrint)

Pretty print JSON objects with line breaks and indentation to make it more human readable.  
If you have an app that writes JSON files that humans need to easily be able to read, run the JSON through this library first.  It doesn't modify the data at all-- only the whitespace.

Turns this:
```js
{ "nestedObject":{ "brad":"wood", "luis":"majano" }, "baz":"bum", "foo":"bar", "nestedArray":[ 1, 2, 3, 4, 5 ], "cool":true }
```
Into this:

```js
{
    "nestedObject":{
        "brad":"wood",
        "luis":"majano"
    },
    "baz":"bum",
    "foo":"bar",
    "nestedArray":[
        1,
        2,
        3,
        4,
        5
    ],
    "cool":true
}

```

## Installation

```
CommandBox> install JSONPrettyPrint
```

## Usage
	
```js
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( '{ "foo" : "bar" }' );
```

Or pass a complex CFML object and it will serialize for you.
	
```js
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( { foo : 'bar' } );
```

You can customize the indent chars used or the line break chars.  The default is an indent of 4 spaces and CRLF for line endings.
	
```js
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( json={ foo : 'bar' }, indent='  ', lineEnding=chr( 10 ) );
```

The `JSONPrettyPrint` is a threadsafe singleton and suitable for injection.  Inject the library like so:

```js
component {
  property name='JSONPrettyPrint' inject;
  
  function writeJSON( required JSON, required path ) {
  	fileWrite( path, JSONPrettyPrint.formatJSON( JSON ) );
  }
}
```
[![Build Status](https://travis-ci.org/Ortus-Solutions/JSONPrettyPrint.svg?branch=master)](https://travis-ci.org/Ortus-Solutions/JSONPrettyPrint)

Pretty print JSON objects with line breaks and indentation to make it more human readable.
If you have an app that writes JSON files that humans need to easily be able to read, run the JSON through this library first.  By default, it doesn't modify the data at all-- only the whitespace. It can, however, sort JSON object keys for you if you wish.

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

You can customize the indent characters and the line break characters used for formatting. The defaults are an indent of 4 spaces, and a CRLF line ending on Windows and LF otherwise. You can also pass in a `sortKeys` argument of `"text"` or `"textnocase"` to have JSONPrettyPrint sort JSON object keys when formatting.

```js
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( json={ foo : 'bar' }, indent='  ', lineEnding=chr( 10 ) );
var formatted = getInstance( 'JSONPrettyPrint' ).formatJSON( json={ b: 1, a: 2 }, sortKeys='text' );
```

`JSONPrettyPrint` is a threadsafe singleton and suitable for injection.  Inject the library like so:

```js
component {
  property name='JSONPrettyPrint' inject;

  function writeJSON( required JSON, required path ) {
    fileWrite( path, JSONPrettyPrint.formatJSON( JSON ) );
  }
}
```

#### Under the Hood

JSONPrettyPrint uses an alternate JSON formatter on Lucee 5. Lucee 5 deserializes JSON to ordered structs and preserves data types accurately when serializing to JSON, so it is possible to use `deserializeJSON()` and then work from native CFML types to print out formatted JSON without losing key order or data types. This approach is advantageous as it results in a  significant performance boost. Adobe ColdFusion does not preserve key order when deserializing and, prior to ACF 2018, it does not accurately serialize to JSON where strings can be cast to boolean or numeric data types. Because of this the Lucee 5 formatter is not used by default. However, if you are using ColdFusion, want the performance boost of the Lucee 5 formatter, and you don't mind the loss of key order or the possible inaccuracy of data types (on versions prior to ACF 2018) you can ask WireBox for the Lucee 5 formatter directly:

```js
component {
  property name='JSONPrettyPrint' inject="CFMLPrinter@JSONPrettyPrint";

  function writeJSON( required JSON, required path ) {
    fileWrite( path, JSONPrettyPrint.formatJSON( JSON ) );
  }
}
```

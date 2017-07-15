# PropertyFile Utility for CFML

`ProperyFile` is a library to make it is easy to load, modify, and store Java property files from CFML without needing to touch any Java.  This library is a single CFC that encapsulates the data and behaviors of a Java properties file in a fluent API.

```js
getInstance( 'propertyFile' )
    .load( myPath )
    .set( 'myProp', 'myValue' )
    .store();
```

## Read files

To use, create an instance of `PropertyFile` and call the `load()` method with the full path to the file you wish to load.

```js
var propertyFile = getInstance( 'propertyFile' ).load( expandPath( 'myFile.properties' ) );
```

## Manipulate properties

We support two ways of interacting with the file.  You can call methods to get/set/remove properties like so:

```js
propertyFile.set( 'myProp', 'myValue' );
propertyFile.get( 'myProp' );
propertyFile.get( 'anotherProp', 'defaultValue' );
propertyFile.exists( 'questionableProp' );
```

Or you can just use the object directly as a struct and we'll treat the public properties with a dab of fairy dust to keep track of them.  This code block does the same as above.

```js
propertyFile.myProp = 'myValue';
propertyFile.myProp;
propertyFile.anotherProp ?: 'defaultValue';
structKeyExists( propertyFile, 'questionableProp' );
```

Note, this method will give you some issues if you happen to have any property names that conflict with built-in method names since they live in the `this` scope too. Also, make sure property names with periods in them are set like `propertyFile[ 'this.is.my.prop' ]` and NOT like `propertyFile.this.is.my.prop`.  The latter will create nested structs instead of a single property which isn't what you want.

## Iterate properties

If you want to get the properties in an iterable form, use this method:
```js
var myStruct = propertyFile.getAsStruct();
for( var prop in myStruct ) {
	writeDump( myStruct[ prop ] );
}
```

## Store properties

To write a properties file back to the same file you read it from use this `store()` method with no arguments.

```js
propertyFile.store();
```

To save what's in memory to a new file (or to save a new properties object that you didn't read in the first place), pass the `path` you want into the `store()` method.

```js
propertyFile.store( expandPath( 'myNewFile.properties' ) );
```

## Method Chaining

All methods in the PropertyFile object that don't return an explicit value will return `this` so you can chain calls like so:

```js
getInstance( 'propertyFile' )
	.load( myPath )
	.set( 'myProp', 'myValue' )
	.set( 'myOtherProp', 'myOtherValue' )
	.store();
```

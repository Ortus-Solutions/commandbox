# jmespath.cfc

An implementation of [JMESPath](https://github.com/boto/jmespath) for ColdFusion. This implementation supports searching JSON documents as well as native Coldfusion structs and arrays.

## Commandbox Installation

```
$ box install jmespath
```

## Basic Usage

Call `JMESPath.search` with a valid JMESPath search expression and data to search. It will return the extracted values.

```javascript
property name="JMESPath" inject="jmespath"; //wirebox

JMESPath = new models.JmesPath(); //Instantiate Object

JMESPath.search({ foo: { bar: { baz: "value" }}}, 'foo.bar') //{baz: "value"}
```

In addition to accessing nested values, you can exact values from arrays.

#### Basic

```javascript
var data = { foo: { bar: { baz: 'correct' } } };
JMESPath.search(data, 'foo'); // {"bar":{"baz":"correct"}}
JMESPath.search(data, 'foo.bar'); // {"baz":"correct"}
JMESPath.search(data, '*.bar'); // {"baz":"correct"}

var data = { one: 1, two: 2, three: 3 };
JMESPath.search(data, 'one < two'); // true
JMESPath.search(data, 'one == two'); // false

var data = { foo: [{ bar: ['one', 'two'] }, { bar: ['three', 'four'] }, { bar: ['five'] }] };
JMESPath.search(data, 'foo[*].bar[1]'); // ["two","four"]
```

#### Slice

```javascript
var data = { foo: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], bar: { baz: 1 } };
JMESPath.search(data, 'foo[10:0:-1]'); // [9,8,7,6,5,4,3,2,1]
```

#### Pipe

```javascript
var data = { foo: [{ bar: [{ baz: 'one' }, { baz: 'two' }] }, { bar: [{ baz: 'three' }, { baz: 'four' }] }] };
JMESPath.search(data, 'foo[*].bar[*] | [0][0]'); // {"baz":"one"}
```

#### Indices

```javascript
var data = { foo: { bar: ['zero', 'one', 'two'] } };
JMESPath.search(data, 'foo.bar[2]'); // "two"
JMESPath.search(data, 'foo.bar[3]'); // null
JMESPath.search(data, 'foo.bar[-1]'); // "two"
```

#### Multiselect

```javascript
var data = { foo: { bar: 1, baz: [2, 3, 4], buz: 2 } };
JMESPath.search(data, 'foo.[bar,baz[0]]'); // [1,2]
JMESPath.search(data, 'foo.[bar,baz[1]]'); // [1,3]
JMESPath.search(data, 'foo.{bar: bar, buz: buz}'); // {"bar":1,"buz":2}
```

#### Current

```javascript
var data = { foo: [{ name: 'a' }, { name: 'b' }], bar: { baz: 'qux' } };
JMESPath.search(data, '@'); // {"foo":[{"name":"a"},{"name":"b"}],"bar":{"baz":"qux"}}
JMESPath.search(data, '@.bar'); // {"baz":"qux"}
JMESPath.search(data, '@.foo[0]'); // {"name":"a"}
```

#### Filters

```javascript
var data = { foo: [{ age: 20 }, { age: 25 }, { age: 30 }] };
JMESPath.search(data, 'foo[?age > `25`]'); // [{"age":30}]
JMESPath.search(data, 'foo[?age >= `25`]'); // [{"age":25},{"age":30}]
JMESPath.search(data, 'foo[?age > `30`]'); // []
JMESPath.search(data, 'foo[?age < `25`]'); // [{"age":20}]
JMESPath.search(data, 'foo[?age <= `25`]'); // [{"age":20},{"age":25}]
JMESPath.search(data, 'foo[?age < `20`]'); // []
JMESPath.search(data, 'foo[?age == `20`]'); // [{"age":20}]
JMESPath.search(data, 'foo[?age != `20`]'); // [{"age":25},{"age":30}]
```

#### Filter boolean functions

```javascript
contains, ends_with, starts_with;
```

#### Math functions

```javascript
abs, avg, ceil, floor, max min, sum
```

#### Sort functions

```javascript
sort, sort_by, max_by, min_by, reverse;
```

#### Conversion functions

```javascript
to_array, to_string, to_number, to_entries;
```

**[See the JMESPath specification for a full list of supported search expressions.](http://jmespath.org/specification.html)**

## JSON Documents

If you have JSON documents on disk, or IO objects that contain JSON documents, you can pass them as the data argument.

```javascript
JMESPath.search(expression, expandPath('/path/to/data.json'));

fileContent = fileRead(expandPath('./path/to/data.json'), 'utf-8');
JMESPath.search(expression, fileContent);
```

## Links of Interest

-   [License](http://www.apache.org/licenses/LICENSE-2.0)
-   [JMESPath Tutorial](http://jmespath.org/tutorial.html)
-   [JMESPath Specification](http://jmespath.org/specification.html)

## License

This library is distributed under the apache license, version 2.0

> Copyright 2021 Scott Steinbeck; All rights reserved.
>
> Licensed under the apache license, version 2.0 (the "license");
> You may not use this library except in compliance with the license.
> You may obtain a copy of the license at:
>
> http://www.apache.org/licenses/license-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the license is distributed on an "as is" basis,
> without warranties or conditions of any kind, either express or
> implied.
>
> See the license for the specific language governing permissions and
> limitations under the license.

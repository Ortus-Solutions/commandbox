component displayname="runtime" {

    // Type constants used to define functions.
    variables.TOK_EXPREF = "Expref";
    variables.TYPE_NUMBER = 1;
    variables.TYPE_ANY = 2;
    variables.TYPE_STRING = 3;
    variables.TYPE_ARRAY = 4;
    variables.TYPE_OBJECT = 5;
    variables.TYPE_BOOLEAN = 6;
    variables.TYPE_EXPREF = 7;
    variables.TYPE_NULL = 8;
    variables.TYPE_ARRAY_NUMBER = 9;
    variables.TYPE_ARRAY_STRING = 10;
    variables.TYPE_NAME_TABLE = {
        1: 'number',
        2: 'any',
        3: 'string',
        4: 'array',
        5: 'object',
        6: 'boolean',
        7: 'expression',
        8: 'null',
        9: 'Array<number>',
        10: 'Array<string>'
    };

    function init() {
        if(!APPLICATION.keyExists("jmesPathTreeInterpreter"))  APPLICATION.jmesPathTreeInterpreter = new TreeInterpreter();
        this._interpreter = APPLICATION.jmesPathTreeInterpreter;

        this.functionTable = {
            // name: [function, <signature>]
            // The <signature> can be:
            //
            // {
            //   args: [[type1, type2], [type1, type2]],
            //   variadic: true|false
            // }
            //
            // Each arg in the arg list is a list of valid types
            // (if the function is overloaded and supports multiple
            // types.  If the type is "any" then no type checking
            // occurs on the argument.  Variadic is optional
            // and if not provided is assumed to be false.
            abs: {_func: this._functionAbs, _signature: [{types: [TYPE_NUMBER]}]},
            avg: {_func: this._functionAvg, _signature: [{types: [TYPE_ARRAY_NUMBER]}]},
            ceil: {_func: this._functionCeil, _signature: [{types: [TYPE_NUMBER]}]},
            key_contains: {
                _func: this._functionKeyContains,
                _signature: [{types: [TYPE_OBJECT]}, {types: [TYPE_STRING]}]
            },
            contains: {
                _func: this._functionContains,
                _signature: [{types: [TYPE_STRING, TYPE_ARRAY]}, {types: [TYPE_ANY]}]
            },
            matches: {
                _func: this._functionMatches,
                _signature: [{types: [TYPE_STRING, TYPE_ARRAY]}, {types: [TYPE_ANY]}]
            },
            'ends_with': {_func: this._functionEndsWith, _signature: [{types: [TYPE_STRING]}, {types: [TYPE_STRING]}]},
            floor: {_func: this._functionFloor, _signature: [{types: [TYPE_NUMBER]}]},
            join: {_func: this._functionJoin, _signature: [{types: [TYPE_STRING]},{types: [TYPE_ARRAY]}]},
            length: {_func: this._functionLength, _signature: [{types: [TYPE_STRING, TYPE_ARRAY, TYPE_OBJECT]}]},
            map: {_func: this._functionMap, _signature: [{types: [TYPE_EXPREF]}, {types: [TYPE_ARRAY]}]},
            max: {_func: this._functionMax, _signature: [{types: [TYPE_ARRAY_NUMBER, TYPE_ARRAY_STRING]}]},
            'merge': {_func: this._functionMerge, _signature: [{types: [TYPE_OBJECT], variadic: true}]},
            'max_by': {_func: this._functionMaxBy, _signature: [{types: [TYPE_ARRAY]}, {types: [TYPE_EXPREF]}]},
            sum: {_func: this._functionSum, _signature: [{types: [TYPE_ARRAY_NUMBER]}]},
            'starts_with': {
                _func: this._functionStartsWith,
                _signature: [{types: [TYPE_STRING]}, {types: [TYPE_STRING]}]
            },
            min: {_func: this._functionMin, _signature: [{types: [TYPE_ARRAY_NUMBER, TYPE_ARRAY_STRING]}]},
            'min_by': {_func: this._functionMinBy, _signature: [{types: [TYPE_ARRAY]}, {types: [TYPE_EXPREF]}]},
            type: {_func: this._functionType, _signature: [{types: [TYPE_ANY]}]},
            keys: {_func: this._functionKeys, _signature: [{types: [TYPE_OBJECT]}]},
            values: {_func: this._functionValues, _signature: [{types: [TYPE_OBJECT]}]},
            sort: {_func: this._functionSort, _signature: [{types: [TYPE_ARRAY_STRING, TYPE_ARRAY_NUMBER]}]},
            'sort_by': {_func: this._functionSortBy, _signature: [{types: [TYPE_ARRAY]}, {types: [TYPE_EXPREF]}]},
            toList: {_func: this._functiontoList, _signature: [{types: [TYPE_STRING]}, {types: [TYPE_ARRAY_STRING]}]},
            reverse: {_func: this._functionReverse, _signature: [{types: [TYPE_STRING, TYPE_ARRAY]}]},
            'to_array': {_func: this._functionToArray, _signature: [{types: [TYPE_ANY]}]},
            'to_entries': {_func: this._functionToEntries, _signature: [{types: [TYPE_OBJECT]}]},
            'to_string': {_func: this._functionToString, _signature: [{types: [TYPE_ANY]}]},
            'to_number': {_func: this._functionToNumber, _signature: [{types: [TYPE_ANY]}]},
            'not_null': {_func: this._functionNotNull, _signature: [{types: [TYPE_ANY], variadic: true}]}
        };
    }




    function callFunction(name, resolvedArgs) {
        if (!this.functionTable.keyExists(name)) {
            throw (type="JMESError", message=  'Unknown function: ' &  name &  '()');
        } else {
            var functionEntry = this.functionTable[name];
        }
        this._validateArgs(name, resolvedArgs, functionEntry._signature);
        //dump({name: functionEntry,args:        resolvedArgs});
        return functionEntry._func(resolvedArgs);
    }
    function _validateArgs(name, args, signature) {
        // Validating the args requires validating
        // the correct arity and the correct type of each arg.
        // If the last argument is declared as variadic, then we need
        // a minimum number of args to be required.  Otherwise it has to
        // be an exact amount.
        var pluralized;
        if (signature[signature.len()].keyExists('variadic') && signature[signature.len()].variadic) {
            if (args.len() < signature.len()) {
                pluralized = signature.len() == 1 ? ' argument' : ' arguments';
                throw (type="JMESError", message=
                    'ArgumentError: ' &  name &  '() ' &
                    'takes at least' &  signature.len() &  pluralized &
                    ' but received ' &  args.len()
                );
            }
        } else if (args.len() != signature.len()) {
            pluralized = signature.len() == 1 ? ' argument' : ' arguments';
            throw (type="JMESError", message=
                'ArgumentError: ' &  name &  '() ' &
                'takes ' &  signature.len() &  pluralized &
                ' but received ' &  args.len()
            );
        }
        var currentSpec;
        var actualType;
        var typeMatched;
        for (var i = 1; i <= signature.len(); i++) {
            typeMatched = false;
            currentSpec = signature[i].types;
            actualType = this._getTypeName(args[i]);
            for (var j = 1; j <= currentSpec.len(); j++) {
                if (this._typeMatches(actualType, currentSpec[j], args[i])) {
                    typeMatched = true;
                    break;
                }
            }
            if (!typeMatched) {
                var expected = currentSpec
                    .map(function(typeIdentifier) {
                        return TYPE_NAME_TABLE[typeIdentifier];
                    })
                    .toList(',');
                throw (type="JMESError", message=
                    'TypeError: ' &  name &  '() ' &
                    'expected argument ' &  (i +  1) &
                    ' to be type ' &  expected &
                    ' but received type ' &
                    TYPE_NAME_TABLE[actualType] &  ' instead.'
                );
            }
        }
    }
    function _typeMatches(actual, expected, argValue) {
        if (expected == TYPE_ANY) {
            return true;
        }
        if (
            expected == TYPE_ARRAY_STRING ||
            expected == TYPE_ARRAY_NUMBER ||
            expected == TYPE_ARRAY
        ) {
            // The expected type can either just be array,
            // or it can require a specific subtype (array of numbers).
            //
            // The simplest case is if "array" with no subtype is specified.
            if (expected == TYPE_ARRAY) {
                return actual == TYPE_ARRAY;
            } else if (actual == TYPE_ARRAY) {
                // Otherwise we need to check subtypes.
                // I think this has potential to be improved.
                var subtype;
                if (expected == TYPE_ARRAY_NUMBER) {
                    subtype = TYPE_NUMBER;
                } else if (expected == TYPE_ARRAY_STRING) {
                    subtype = TYPE_STRING;
                }
                for (var i = 1; i <= argValue.len(); i++) {
                    if (!this._typeMatches(this._getTypeName(argValue[i]), subtype, argValue[i])) {
                        return false;
                    }
                }
                return true;
            }
        } else {
            return actual == expected;
        }
    }

    function _getTypeName(obj) {
        //echo(serializeJSON(obj) & " -> " & getMetaData(obj).getName() & "<br/>")
        if(isNull(obj)) return TYPE_NULL;
        if(getMetaData(obj).getName() == 'java.lang.String') return TYPE_STRING;
        if(getMetaData(obj).getName() == 'java.lang.Boolean') return TYPE_BOOLEAN;
        if(getMetaData(obj).getName() == 'java.lang.Double') return TYPE_NUMBER;
        if(getMetaData(obj).getName() == 'lucee.runtime.type.ArrayImpl') return TYPE_ARRAY;
        if(getMetaData(obj).getName() == 'lucee.runtime.type.StructImpl'){
            if (structKeyExists(obj,'jmespathType') && obj.jmespathType == TOK_EXPREF) {
                return TYPE_EXPREF;
            } else {
                return TYPE_OBJECT;
            }
        }
    }


    function _functionStartsWith(resolvedArgs) {
        return resolvedArgs[1].lastIndexOf(resolvedArgs[2]) == 0;
    }
    function _functionEndsWith(resolvedArgs) {
        var searchStr = resolvedArgs[1];
        var suffix = resolvedArgs[2];
        return searchStr.indexOf(suffix, searchStr.len() - suffix.len()) != -1;
    }
    function _functionReverse(resolvedArgs) {
        var typeName = this._getTypeName(resolvedArgs[1]);
        if (typeName == TYPE_STRING) {
            var originalStr = resolvedArgs[1];
            return reverse(resolvedArgs[1]);
        } else {
            var reversedArray = resolvedArgs[1];
            reversedArray = reversedArray.reverse();
            return reversedArray;
        }
    }
    function _functionAbs(resolvedArgs) {
        return abs(resolvedArgs[1]);
    }
    function _functionCeil(resolvedArgs) {
        return ceiling(resolvedArgs[1]);
    }
    function _functionAvg(resolvedArgs) {
        var sum = 0;
        var inputArray = resolvedArgs[1];
        for (var i = 1; i <= inputArray.len(); i++) {
            sum += inputArray[i];
        }
        return sum / inputArray.len();
    }
    function _functionKeyContains(resolvedArgs) {
		var items = {};
		for( var i in resolvedArgs[1]){
			if(i.find(resolvedArgs[2]) > 0) items[i] = resolvedArgs[1][i];
		}
        return items;
    }
    function _functionContains(resolvedArgs) {
        return resolvedArgs[1].find(resolvedArgs[2]) > 0;
    }
    function _functionMatches(resolvedArgs) {
		var regexVal  = replace(resolvedArgs[2],"\\","\","All");
        return resolvedArgs[1].refind(regexVal) > 0;
    }
    function _functionFloor(resolvedArgs) {
        return floor(resolvedArgs[1]);
    }
    function _functionJoin(resolvedArgs){
        return arrayToList(resolvedArgs[2],resolvedArgs[1]);
    }
    function _functionLength(resolvedArgs) {
        if (!isStruct(resolvedArgs[1])) {
            return resolvedArgs[1].len();
        } else {
            // As far as I can tell, there's no way to get the length
            // of an object without O(n) iteration through the object.
            return structCount(resolvedArgs[1]);
        }
    }
    function _functionMap(resolvedArgs) {
        var mapped = [];
        var interpreter = this._interpreter;
        var exprefNode = resolvedArgs[1];
        var elements = resolvedArgs[2];
        for (var i = 1; i <= elements.len(); i++) {
            mapped.append(interpreter.visit(exprefNode, elements[i]));
        }
        return mapped;
    }
    function _functionMerge(resolvedArgs) {
        var merged = {};
        for (var i = 1; i <= resolvedArgs.len(); i++) {
            var current = resolvedArgs[i];
            for (var key in current) {
                merged[key] = current[key];
            }
        }
        return merged;
    }
    function _functionMax(resolvedArgs) {
        if (resolvedArgs[1].len() > 0) {
            var typeName = this._getTypeName(resolvedArgs[1][1]);
            if (typeName == TYPE_NUMBER) {
                return arrayMax(resolvedArgs[1]);
            } else {
                var elements = resolvedArgs[1];
                var maxElement = elements[1];
                for (var i = 2; i <= elements.len(); i++) {
                    if (maxElement.find(elements[i]) <= 0) {
                        maxElement = elements[i];
                    }
                }
                return maxElement;
            }
        } else {
            return nullValue();
        }
    }
    function _functionMin(resolvedArgs) {
        if (resolvedArgs[1].len() > 0) {
            var typeName = this._getTypeName(resolvedArgs[1][1]);
            if (typeName == TYPE_NUMBER) {
                return arrayMin(resolvedArgs[1]);
            } else {
                var elements = resolvedArgs[1];
                var minElement = elements[1];
                for (var i = 2; i <= elements.len(); i++) {
                    if (elements[i] < minElement) {
                        minElement = elements[i];
                    }
                }
                return minElement;
            }
        } else {
            return nullValue();
        }
    }
    function _functionSum(resolvedArgs) {
        var sum = 0;
        var listToSum = resolvedArgs[1];
        for (var i = 1; i <= listToSum.len(); i++) {
            sum += listToSum[i];
        }
        return sum;
    }
    function _functionType(resolvedArgs) {
        switch (this._getTypeName(resolvedArgs[1])) {
            case TYPE_NUMBER:
                return 'number';
            case TYPE_STRING:
                return 'string';
            case TYPE_ARRAY:
                return 'array';
            case TYPE_OBJECT:
                return 'object';
            case TYPE_BOOLEAN:
                return 'boolean';
            case TYPE_EXPREF:
                return 'expref';
            case TYPE_NULL:
                return 'null';
        }
    }
    function _functionKeys(resolvedArgs) {
        return structKeyArray(resolvedArgs[1]);
    }
    function _functionValues(resolvedArgs) {
        var obj = resolvedArgs[1];
        var keys = structKeyArray(obj);
        var values = [];
        for (var i = 1; i <= keys.len(); i++) {
            values.append(obj[keys[i]]);
        }
        return values;
    }
    function _functionToEntries(resolvedArgs) {
        var obj = resolvedArgs[1];
        var keys = structKeyArray(obj);
        var values = [];
        for (var i = 1; i <= keys.len(); i++) {
            values.append({ 'key': keys[i], 'value':obj[keys[i]]});
        }
        return values;
    }
    function _functiontoList(resolvedArgs) {
        var toListChar = resolvedArgs[1];
        var listtoList = resolvedArgs[2];
        return listtoList.toList(toListChar);
    }
    function _functionToArray(resolvedArgs) {
        if (this._getTypeName(resolvedArgs[1]) == TYPE_ARRAY) {
            return resolvedArgs[1];
        } else {
            return [resolvedArgs[1]];
        }
    }
    function _functionToString(resolvedArgs) {
        if (this._getTypeName(resolvedArgs[1]) == TYPE_STRING) {
            return resolvedArgs[1];
        } else {
            return serializeJSON(resolvedArgs[1]);
        }
    }
    function _functionToNumber(resolvedArgs) {
        var typeName = this._getTypeName(resolvedArgs[1]);
        var convertedValue;
        if (typeName == TYPE_NUMBER) {
            return resolvedArgs[1];
        } else if (typeName == TYPE_STRING) {
            try {
                convertedValue = ParseNumber(resolvedArgs[1]);
                if (isNumeric(convertedValue)) {
                    return convertedValue;
                }
            } catch( any e){
                throw (type="JMESError", message= 'ParseError: String "' & resolvedArgs[1] & '" cannot be parsed as number');

            }
        }
        return nullValue();
    }
    function _functionNotNull(resolvedArgs) {
        for (var i = 1; i <= resolvedArgs.len(); i++) {
            if (this._getTypeName(resolvedArgs[i]) != TYPE_NULL) {
                return resolvedArgs[i];
            }
        }
        return nullValue();
    }
    function _functionSort(resolvedArgs) {
        var sortedArray = resolvedArgs[1];
        sortedArray.sort('textnocase');
        return sortedArray;
    }

    function _functionSortBy(resolvedArgs) {
        var sortedArray = resolvedArgs[1];
        if (sortedArray.len() == 0) {
            return sortedArray;
        }
        var interpreter = this._interpreter;
        var exprefNode = resolvedArgs[2];
        var requiredType = this._getTypeName(interpreter.visit(exprefNode, sortedArray[1]));
        if ([TYPE_NUMBER, TYPE_STRING].indexOf(requiredType) < 0) {
            throw (type="JMESError", message= 'TypeError');
        }
        var that = this;
        // In order to get a stable sort out of an unstable
        // sort algorithm, we decorate/sort/undecorate (DSU)
        // by creating a new list of [index, element] pairs.
        // In the cmp function, if the evaluated elements are
        // equal, then the index will be used as the tiebreaker.
        // After the decorated list has been sorted, it will be
        // undecorated to extract the original elements.
        var decorated = [];
        for (var i = 1; i <= sortedArray.len(); i++) {
            decorated.append([i, sortedArray[i]]);
        }
        decorated.sort(function(a, b) {
            var exprA = interpreter.visit(exprefNode, a[2]);
            var exprB = interpreter.visit(exprefNode, b[2]);
            if (that._getTypeName(exprA) != requiredType) {
                throw (type="JMESError", message=
                    'TypeError: expected ' &  requiredType &  ', received ' &
                    that._getTypeName(exprA)
                );
            } else if (that._getTypeName(exprB) != requiredType) {
                throw (type="JMESError", message=
                    'TypeError: expected ' &  requiredType &  ', received ' &
                    that._getTypeName(exprB)
                );
            }
            if (exprA > exprB) {
                return 1;
            } else if (exprA < exprB) {
                return -1;
            } else {
                // If they're equal compare the items by their
                // order to maintain relative order of equal keys
                // (i.e. to get a stable sort).
                return a[1] - b[1];
            }
        });
        // Undecorate: extract out the original list elements.
        for (var j = 1; j <= decorated.len(); j++) {
            sortedArray[j] = decorated[j][2];
        }
        return sortedArray;
    }
    function _functionMaxBy(resolvedArgs) {
        var exprefNode = resolvedArgs[2];
        var resolvedArray = resolvedArgs[1];
        var keyFunction = this.createKeyFunction(exprefNode, [TYPE_NUMBER, TYPE_STRING]);
        var maxNumber = Javacast('double',1).NEGATIVE_INFINITY;
        var maxRecord;
        var current;
        for (var i = 1; i <= resolvedArray.len(); i++) {
            current = keyFunction(resolvedArray[i]);
            if (current > maxNumber) {
                maxNumber = current;
                maxRecord = resolvedArray[i];
            }
        }
        return maxRecord;
    }
    function _functionMinBy(resolvedArgs) {
        var exprefNode = resolvedArgs[2];
        var resolvedArray = resolvedArgs[1];
        var keyFunction = this.createKeyFunction(exprefNode, [TYPE_NUMBER, TYPE_STRING]);
        var minNumber = Javacast('double',1).POSITIVE_INFINITY;
        var minRecord;
        var current;
        for (var i = 1; i <= resolvedArray.len(); i++) {
            current = keyFunction(resolvedArray[i]);
            if (current < minNumber) {
                minNumber = current;
                minRecord = resolvedArray[i];
            }
        }
        return minRecord;
    }
    function createKeyFunction(exprefNode, allowedTypes) {
        var that = this;
        var interpreter = this._interpreter;
        var keyFunc = function(x) {
            var current = interpreter.visit(exprefNode, x);
            if (allowedTypes.indexOf(that._getTypeName(current)) < 0) {
                var msg = 'TypeError: expected one of ' &  allowedTypes &
                ', received ' &  that._getTypeName(current);
                throw (type="JMESError", message= msg);
            }
            return current;
        };
        return keyFunc;
    }

}

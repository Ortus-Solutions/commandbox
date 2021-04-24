component singleton displayname="TreeInterpreter" {
	property name="jmesPathRuntime" inject="Runtime@JMESPath";

    TOK_EOF = 'EOF';
    TOK_UNQUOTEDIDENTIFIER = 'UnquotedIdentifier';
    TOK_QUOTEDIDENTIFIER = 'QuotedIdentifier';
    TOK_RBRACKET = 'Rbracket';
    TOK_RPAREN = 'Rparen';
    TOK_COMMA = 'Comma';
    TOK_COLON = 'Colon';
    TOK_RBRACE = 'Rbrace';
    TOK_NUMBER = 'Number';
    TOK_CURRENT = 'Current';
    TOK_EXPREF = 'Expref';
    TOK_PIPE = 'Pipe';
    TOK_OR = 'Or';
    TOK_AND = 'And';
    TOK_EQ = 'EQ';
    TOK_GT = 'GT';
    TOK_LT = 'LT';
    TOK_GTE = 'GTE';
    TOK_LTE = 'LTE';
    TOK_NE = 'NE';
    TOK_FLATTEN = 'Flatten';
    TOK_STAR = 'Star';
    TOK_FILTER = 'Filter';
    TOK_DOT = 'Dot';
    TOK_NOT = 'Not';
    TOK_LBRACE = 'Lbrace';
    TOK_LBRACKET = 'Lbracket';
    TOK_LPAREN = 'Lparen';
    TOK_LITERAL = 'Literal';

    function strictDeepEqual(first, second) {
        if(isNull(first) && isNull(second)) return true;
        if(isNull(first) || isNull(second)) return false;
        if(getMetadata(first).getName() != getMetadata(second).getName() ) return false;
        if(isSimpleValue(first) && first == second ){
            return true;
        }

        // We know that first and second have the same type so we can just check the
        // first type from now on.1
        if (isArray(first) && isArray(second)) {
            // Short circuit if they're not the same length;
            if (first.len() != second.len()) {
                return false;
            }
            for (var i = 1; i <= first.len(); i++) {
                if (strictDeepEqual(first[i], second[i]) == false) {
                    return false;
                }
            }
            return true;
        }
        if (isStruct(first)  && isStruct(second)) {
            // echo('we are here')
            // An object is equal if it has the same key/value pairs.
            var keysSeen = {};
            for (var key in first) {
                // echo('first -> ' & key & '<br/>');
                if (structKeyExists(first, key) && structKeyExists(second,key)) {
                    if (strictDeepEqual(first[key], second[key]) == false) {
                        return false;
                    }
                    keysSeen[key] = true;
                }
            }
            // Now check that there aren't any keys in second that weren't
            // in first.
            for (var key2 in second) {
                // echo('second -> ' & key2 &  '<br/>');
                if (!structKeyExists(second, key2) || !structKeyExists(keysSeen,key2)) {
                        return false;
                }
            }
            return true;
        }
        return false;
    }
    function isFalse(obj) {
        //// echo("isFalse check: " & serializeJSON(obj) & " = ");
        // From the spec:
        // A false value corresponds to the following values:
        // Empty list
        // Empty object
        // Empty string
        // False boolean
        // First check the scalar values.
        // null value
        if(isNull(obj) ) return true;
        if(isNumeric(obj)) return false;
        if(isBoolean(obj)) return !obj;

        if ((isSimpleValue(obj) && obj == '' && obj != 0)) {
            return true;
        } else if (isArray(obj) && obj.len() == 0) {
            // Check for an empty array.
            return true;
        } else if (isStruct(obj)) {
            // Check for an empty object.
            for (var key in obj) {
                // If there are any keys, then
                // the object is not empty so the object
                // is not false.
                if (obj.keyExists(key)) {
                    // echo("true<br/>");
                    return false;
                }
            }
            // echo("true<br/>");
            return true;
        } else {
             // echo("false<br/>");
            return false;
        }
    }
    function objValues(obj) {
        var keys = structKeyArray(obj);
        var values = [];
        for (var i = 1; i <= keys.len(); i++) {
            values.append(obj[keys[i]]);
        }
        return values;
    }
    function merge(a, b) {
        var merged = {};
        for (var key in a) {
            merged[key] = a[key];
        }
        for (var key2 in b) {
            merged[key2] = b[key2];
        }
        return merged;
    }
    function trimLeft(str) {
        // return str.match(/^\s*(.*)/)[2];
    }
    function search(node, value) {

        return this.visit(node, value);
    }
    function visit(node, value) {
        // echo(serializeJSON(node) & "[ " & node.type & " ] " & serializeJSON(value) & "<br/>");
        var  matched;
        var  current;
        var  result;
        var  first;
        var  second;
        var  field;
        var  left;
        var  right;
        var  collected;
        var  i;
        switch (node.type) {
            case 'Field':
                if (!isNull(value) && isStruct(value)) {
                    if (!value.keyExists(node.name)) {
                        // echo(" = structNull" & "<br/>")
                        return;
                    } else {
						field = value[node.name];
                        return field;
                    }
                }
                // echo(" = Null" & "<br/>")
                return;
            case 'Subexpression':
                result = this.visit(node.children[1], value);
                if (isNull(result))  return;
                for (i = 2; i <= node.children.len(); i++) {
                    result = this.visit(node.children[2], result);
                    if (isNull(result))  return;
                }
                return result;
            case 'IndexExpression':
                left = this.visit(node.children[1], value) ?: NullValue();
                if(isNull(left)) return;
                right = this.visit(node.children[2], left) ?: NullValue();
                if(isNull(right)) return;
                return right;
            case 'Index':
                if (!isArray(value)) {
                    return;
                }
                var index = node.value;
                if (index < 0) {
                    index = value.len()  + index + 1;
                } else {
                    index++; // to account for coldfusion starting at 1
                }
                if (!value.indexExists(index)) {
                    return;
                }
                result = value[index];
                return result;
            case 'Slice':
                if (!isArray(value)) {
                    return;
                }
                var sliceParams = (node.children);
                var computed = this.computeSliceParams(value.len(), sliceParams);
                var start = computed[1];
                var stop = computed[2];
                var step = computed[3];
                result = [];
                if (step > 0) {
                    for (i = start; i <= stop; i += step) {
                        result.append(value[i]);
                    }
                } else {
                    for (i = start; i >= stop; i += step) {
                        result.append(value[i]);
                    }
                }
                return result;
            case 'Projection':
                // Evaluate left child.
                var base = this.visit(node.children[1], value);
                if (isNull(base) || !isArray(base)) {
                    return;
                }
                collected = [];
                for (i = 1; i <= base.len(); i++) {
                    current = this.visit(node.children[2], base[i]);
                    if (!isNull(current)) {
                        collected.append(current);
                    }
                }
                return collected;
            case 'ValueProjection':
                // Evaluate left child.
                base = this.visit(node.children[1], value);
                if (isNull(base) || !isStruct(base)) {
                    return;
                }
                collected = [];
                var values = objValues(base);
                for (i = 1; i <= values.len(); i++) {
                    current = this.visit(node.children[2], values[i]);
                    if (!isNull(current)) {
                        collected.append(current);
                    }
                }
                return collected;
            case 'FilterProjection':
                base = this.visit(node.children[1], value);
                if (isNull(base) || !isArray(base)) {
                    return;
                }
                var filtered = [];
                var finalResults = [];
                for (i = 1; i <= base.len(); i++) {
                    matched = this.visit(node.children[3], base[i]);
                    if (!isNull(matched) && !isFalse(matched)) {
                        filtered.append(base[i]);
                    }
                }
                for (var j = 1; j <=filtered.len(); j++) {
                    current = this.visit(node.children[2], filtered[j]);
                    if (!isNull(current)) {
                        finalResults.append(current);
                    }
                }
                return finalResults;
            case 'Comparator':
                first = this.visit(node.children[1], value);
                second = this.visit(node.children[2], value);
                switch (node.name) {
                    case TOK_EQ:
                        result = strictDeepEqual(first ?: NullValue(), second ?: NullValue());
                        break;
                    case TOK_NE:
                        result = !strictDeepEqual(first ?: NullValue(), second ?: NullValue());
                        break;
                    case TOK_GT:
                        result = first > second;
                        break;
                    case TOK_GTE:
                        result = first >= second;
                        break;
                    case TOK_LT:
                        result = first < second;
                        break;
                    case TOK_LTE:
                        result = first <= second;
                        break;
                    default:
                        throw (type="JMESError", detail='Unknown comparator: ' + node.name);
                }
                return result;
            case TOK_FLATTEN:
                var original = this.visit(node.children[1], value);
                if (isNull(original) || !isArray(original)) {
                    return;
                }
                var merged = [];
                for (i = 1; i <= original.len(); i++) {
                    current = original[i];
                    if (isArray(current)) {
                        merged = merged.merge(current);
                    } else {
                        merged.append(current);
                    }
                }
                return merged;
            case 'Identity':
                return value;
            case 'MultiSelectList':
                if (isNull(value)) {
                    return;
                }
                collected = [];
                for (i = 1; i <= node.children.len(); i++) {
                    collected.append(this.visit(node.children[i], value));
                }
                return collected;
            case 'MultiSelectHash':
                if (isNull(value)) {
                    return;
                }
                collected = {};
                var child;
                for (i = 1; i <= node.children.len(); i++) {
                    child = node.children[i];
                    collected[child.name] = this.visit(child.value, value);
                }
                return collected;
            case 'OrExpression':
                matched = this.visit(node.children[1], value);
                if (isNull(matched) || isFalse(matched)) {
                    return this.visit(node.children[2], value);
                }
                return matched;
            case 'AndExpression':
                first = this.visit(node.children[1], value);
                if (isFalse(first) == true) {
                    return first;
                }
                return this.visit(node.children[2], value);
            case 'NotExpression':
                first = this.visit(node.children[1], value);
                return isNull(first) || isFalse(first);
            case 'Literal':
                return node.value;
            case TOK_PIPE:
                left = this.visit(node.children[1], value);
                if(isNull(left)) return;
                return this.visit(node.children[2], left);
            case TOK_CURRENT:
                return value;
            case 'Function':
                var resolvedArgs = [];
                for (i = 1; i <= node.children.len(); i++) {
                    resolvedArgs.append(this.visit(node.children[i], value));
                }
                return jmesPathRuntime.callFunction(node.name, resolvedArgs);
            case 'ExpressionReference':
                var refNode = node.children[1];
                // Tag the node with a specific attribute so the type
                // checker verify the type.
                refNode.jmespathType = TOK_EXPREF;
                return refNode;
            default:
                throw(type="JMESError", detail='Unknown node type: ' + node.type);
        }
    }

    function computeSliceParams(arrayLength, sliceParams) {
        var start = sliceParams[1] ?: NullValue();
        var stop = sliceParams[2] ?: NullValue();
        var step = sliceParams[3] ?: NullValue();
        var computed = [nullvalue(), nullvalue(), nullvalue()];
        if (isNull(step)) {
            step = 1;
        } else if (step === 0) {
            throw(type="RuntimeError", detail='Invalid slice, step cannot be 0');
        }
        var stepValueNegative = step < 0 ? true : false;

        if (isNull(start)) {
            start = stepValueNegative ? arrayLength - 1 : 0;
        } else {
            start = capSliceRange(arrayLength, start, step);
        }

        if (isNull(stop)) {
            stop = stepValueNegative ? -1 : arrayLength;
        } else {
            stop = capSliceRange(arrayLength, stop, step);
        }
        if(start < stop){
            start+=1;
        } else if (start > stop){
            start+=1;
            stop+=2;
        }
        computed[1] = start;
        computed[2] = stop;
        computed[3] = step;
        return computed;
    }

    function capSliceRange (arrayLength, actualValue, step) {
        if (actualValue < 0) {
            actualValue += arrayLength;
            if (actualValue < 0) {
                actualValue = step < 0 ? -1 : 0;
            }
        } else if (actualValue >= arrayLength) {
            actualValue = step < 0 ? arrayLength - 1 : arrayLength;
        }
        return actualValue;
    }

}

module tvm.compiler.printer;

import std.string : format;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;

string toString(TVMValue value) {
    switch(value.type) {
        case TVMValue.POINTER:
            return toString(value.value!TVMPointer);

        case TVMValue.FLOATING:
            return format("%f", value.value!double);

        case TVMValue.INTEGER:
            return format("%d", value.value!long);

        default:
            assert(0, "Bad type!");
    }
}

string toString(TVMPointer object) {
    if(isNil(object)) return "()";

    switch(object.type) {
        case TVMObject.SYMBOL:
            return toString(cast(TVMSymbolPtr) object);

        case TVMObject.PAIR:
            return toString(cast(TVMPairPtr) object);

        case TVMObject.CLOSURE:
            return toString(cast(TVMClosurePtr) object);

        case TVMObject.UPROC:
            return toString(cast(TVMMicroProcPtr) object);

        default:
            assert(0, "Bad type!");
    }
}
string toString(TVMSymbolPtr symbol) {
    return symbol.str;
}

string toString(TVMPairPtr pair) {
    return format("(%s . %s)", toString(pair.car), toString(pair.cdr));
}

string toString(TVMClosurePtr closure) {
    return format("#{%s, %s}", toString(closure.code), toString(closure.env));
}

string toString(TVMMicroProcPtr uProc) {
    return format("#%d{%d}", uProc.priority, uProc.asleep ? uProc.wakeTime : uProc.vRunTime);
}

string print(T)(T thing) {
    return toString(thing);
}
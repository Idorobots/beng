module tvm.compiler.printer;

import std.string : format;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;

string toString(TVMInstruction instr) {
    switch(instr.opcode) {
        case TVMInstruction.PUSH:
            return format("PUSH %s", toString(instr.argument));

        case TVMInstruction.TAKE:
            return format("TAKE %s", toString(instr.argument));

        case TVMInstruction.ENTER:
            return format("ENTER %s", toString(instr.argument));

        case TVMInstruction.PRIMOP:
            return format("PRIMOP %s", toString(instr.argument));

        case TVMInstruction.COND:
            return format("COND %s", toString(instr.argument));

        case TVMInstruction.RETURN:
            return "RETURN";

        case TVMInstruction.HALT:
            return "HALT";

        default:
            return format("OP0x%x %s", instr.opcode, toString(instr.argument));
    }
}

string toString(TVMValue value) {
    switch(value.type) {
        case TVMValue.POINTER:
            return toString(value.ptr);

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
            return toString(asSymbol(object));

        case TVMObject.PAIR:
            return toString(asPair(object));

        case TVMObject.CLOSURE:
            return toString(asClosure(object));

        case TVMObject.UPROC:
            return toString(asMicroProc(object));

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
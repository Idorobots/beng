module tvm.compiler.printer;

import std.string : format;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.primops;

string toString(TVMValue value) {
    switch(value.type) {
        case TVMValue.POINTER:
            return toString(value.ptr);

        case TVMValue.FLOATING:
            return format("%s", asFloating(value));

        case TVMValue.INTEGER:
            return format("%s", asInteger(value));

        default:
            assert(0, format("Bad type: %s.", value.type));
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

        case TVMInstruction.INSTRUCTION:
            return toString(asInstruction(object));

        default:
            assert(0, format("Bad type: %s.", object.type));
    }
}

string toString(TVMInstructionPtr instr) {
    auto ops = ["PUSH", "NEXT", "TAKE", "ENTER", "PRIMOP", "COND", "HALT"];
    auto addrs = ["VAL", "ARG", "CODE"];

    if(instr.opcode >= ops.length)
        assert(0, format("Bad bytecode instruction opcode: %s.", instr.opcode));

    if(instr.addressing >= addrs.length)
        assert(0, format("Bad bytecode instruction addressing: %s.", instr.addressing));

    return format("%s %s %s", ops[instr.opcode], addrs[instr.addressing], toString(instr.argument));
}

string toString(TVMSymbolPtr symbol) {
    return "\"" ~ symbol.str ~ "\"";
}

string toString(TVMPairPtr pair) {
    if(isNil(pair))
        return "()";

    string makeString(TVMPairPtr p) {
        TVMValue next = p.cdr;

        if(isPointer(next)) {
            if(isNil(next.ptr))       return toString(p.car);
            else if(isPair(next.ptr)) return toString(p.car) ~ " " ~ makeString(asPair(next.ptr));
            else                      return toString(p.car) ~ " . " ~ toString(p.cdr);
        } else {
            return toString(p.car) ~ " . " ~ toString(p.cdr);
        }
    }
    return "(" ~ makeString(pair) ~ ")";
}

string toString(TVMClosurePtr closure) {
    return format("#{%s, ...}", toString(closure.code));
}

string toString(TVMMicroProcPtr uProc) {
    return format("#%d{%d}", uProc.priority, uProc.asleep ? uProc.wakeTime : uProc.vRunTime);
}

string print(T)(T thing) {
    return toString(thing);
}
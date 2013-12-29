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
    auto addrs = ["VAL", "ARG", "CODE"];

    if(instr.addressing >= addrs.length)
        assert(0, format("Bad bytecode instruction addressing: %s.", instr.addressing));

    switch(instr.opcode) {
        case TVMInstruction.PUSH:
            return format("PUSH %s", toString(instr.argument));

        case TVMInstruction.NEXT:
            return format("NEXT %s %s", addrs[instr.addressing], toString(instr.argument));

        case TVMInstruction.TAKE:
            return "TAKE";

        case TVMInstruction.ENTER:
            return format("ENTER %s %s", addrs[instr.addressing], toString(instr.argument));

        case TVMInstruction.PRIMOP:
            TVMValue arg = instr.argument;
            return format("PRIMOP %s", primopName(arg.integer));

        case TVMInstruction.COND:
            TVMValue arg = instr.argument;
            return format("COND {%s, %s}",
                          toString(asPair(arg.ptr).car),
                          toString(asPair(arg.ptr).cdr));

        case TVMInstruction.HALT:
            return "HALT";

        default:
            assert(0, format("Bad instruction: %s.", instr.opcode));
    }
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
module tvm.compiler.printer;

import std.string : format;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.primops;

string toString(TVMInstruction instr) {
    switch(instr.opcode) {
        case TVMInstruction.PUSH:
            return format("PUSH %s", toString(instr.argument));

        case TVMInstruction.NEXT:
            return format("NEXT %s",
                          isPointer(instr.argument) && isPair(instr.argument.ptr)
                          ? codeToString(asPair(instr.argument.ptr))
                          : toString(instr.argument));

        case TVMInstruction.ENTER:
            return format("ENTER %s", toString(instr.argument));

        case TVMInstruction.PRIMOP:
            return format("PRIMOP %s", primopName(instr.argument.integer));

        case TVMInstruction.COND:
            auto branches = instr.argument.ptr;
            if(isPair(branches) && !isNil(branches)) {
                TVMValue car = asPair(branches).car;
                TVMValue cdr = asPair(branches).cdr;

                return format("COND {%s, %s}",
                              codeToString(asPair(car.ptr)),
                              codeToString(asPair(cdr.ptr)));
            } else {
                assert(0, "Malformed bytecode instruction: " ~ toString(instr.argument) ~ ".");
            }

        case TVMInstruction.TAKE:
            return "TAKE";

        case TVMInstruction.RETURN:
            return "RETURN";

        case TVMInstruction.HALT:
            return "HALT";

        default:
            return format("OP_0x%x %s", instr.opcode, toString(instr.argument));
    }
}

string toString(TVMValue value) {
    switch(value.type) {
        case TVMValue.POINTER:
            // FIXME A hack to avoid bad pointers. :(
            if(value.rawValue > ((0x1UL << 48)) - 1) {
                return toString(asInstruction(value));
            } else {
                return toString(asPointer(value));
            }

        case TVMValue.FLOATING:
            return format("%s", asFloating(value));

        case TVMValue.INTEGER:
            return format("%s", asInteger(value));

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
            assert(0, format("Bad type: %s.", object.type));
    }
}
string toString(TVMSymbolPtr symbol) {
    return "\"" ~ symbol.str ~ "\"";
}

private string listToString(alias as)(TVMPairPtr pair) {
    if(isNil(pair))
        return "()";

    // FIXME This is a direct copy of the AST code. Could be abstracted away.
    string makeString(TVMPairPtr p) {
        TVMValue next = p.cdr;

        if(isPointer(next)) {
            if(isNil(next.ptr))       return toString(as(p.car));
            else if(isPair(next.ptr)) return toString(as(p.car)) ~ " " ~ makeString(asPair(next.ptr));
            else                      return toString(as(p.car)) ~ " . " ~ toString(p.cdr);
        } else {
            return toString(as(p.car)) ~ " . " ~ toString(as(p.cdr));
        }
    }
    return "(" ~ makeString(pair) ~ ")";
}

string toString(TVMPairPtr pair) {
    return listToString!asValue(pair);
}

string toString(TVMClosurePtr closure) {
    TVMValue code = closure.code;
    if(isPair(code.ptr)) {
        return format("#{%s, ...}", codeToString(asPair(code.ptr)));
    } else {
        assert(0, "Malformed bytecode stream.");
    }
}

string toString(TVMMicroProcPtr uProc) {
    return format("#%d{%d}", uProc.priority, uProc.asleep ? uProc.wakeTime : uProc.vRunTime);
}

string codeToString(TVMPairPtr pair) {
    return listToString!asInstruction(pair);
}

string print(T)(T thing) {
    return toString(thing);
}
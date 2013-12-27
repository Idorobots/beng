module tvm.vm.interpreter;

import std.typecons;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.gc;

class RuntimeError : Exception {
    this(string what) {
        super(what);
    }
}

auto fetch(Allocator)(Allocator a, TVMPointer code) {
    if(isNil(code)) {
        return tuple(ret(), code);
    } else {
        auto instrCode = pop(a, code);
        // NOTE Assumes that the value returned is actually an instruction.
        return tuple(asInstruction(instrCode[0]), instrCode[1]);
    }
}

auto pop(Allocator)(Allocator a, TVMPointer stack) {
    if(isPair(stack)) {
        if(!isNil(stack)) {
            auto p = asPair(stack);
            TVMValue rest = p.cdr;

            auto r = tuple(use(p.car), use(rest.ptr)); // Use the two pair parts.
            free(a, stack);                            // Free the pair reference.

            return r;
        } else {
            throw new RuntimeError("Stack underflow!");
        }
    } else {
        throw new RuntimeError("Malformed stack!");
    }
}

TVMPointer push(Allocator)(Allocator a, TVMValue newValue, TVMPointer stack) {
    return asObject(pair(a, newValue, value(stack)));
}

time_t step(time_t time, TVMContext uProc) {
    auto ic = fetch(uProc.alloc, uProc.code);

    auto instruction = ic[0];
    uProc.code = ic[1];

    auto opcode = instruction.opcode;
    auto argument = instruction.argument;

    debug(verbose) {
        import std.stdio;
        import tvm.compiler.printer;

        writeln(time, " uProc #", uProc.priority,
                " interpreting instruction ", print(instruction), "...");
    }

    switch(opcode) {
        case TVMInstruction.PUSH:
            // TODO Push argument onto the stack.
            return 0;

        case TVMInstruction.TAKE:
            // TODO Take an argument from the stack and put it into the env.
            return 0;

        case TVMInstruction.ENTER:
            // TODO Take a closure from the stack and enter it.
            return 0;

        case TVMInstruction.PRIMOP:
            // TODO Apply the primop to the arguments on vstack.
            return 0;

        case TVMInstruction.COND:
            // TODO Check top of the vstack and select one of the alternatives.
            return 0;

        case TVMInstruction.RETURN:
            // TODO Enter the closure on the top of the stack.
            // TODO Do this when code is nil & ensure to add a halt to the uProc code.
            return 0;

        case TVMInstruction.HALT:
            // FIXME This should halt immediately.
            return TVMMicroProc.MAX_SLEEP_TIME;

        default:
            assert(0, "Bad byte code instruction.");
    }
}


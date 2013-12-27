module tvm.vm.interpreter;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.bytecode;

TVMInstruction fetch(TVMPointer IP) {
    // TODO Fetch next instruction.
    return halt();
}

TVMPointer pop(TVMPointer stack) {
    // TODO Pop a value from a list-based stack.
    return stack;
}

TVMPointer push(Allocator)(Allocator a, TVMPointer value, TVMPointer stack) {
    // TODO Push a new value onto the stack.
    return stack;
}

time_t step(time_t time, TVMContext uProc) {
    with(uProc) {
        auto instruction = fetch(code);
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
}


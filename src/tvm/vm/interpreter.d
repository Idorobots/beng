module tvm.vm.interpreter;

import std.typecons;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.primops;
import tvm.vm.gc;

class RuntimeError : Exception {
    this(string what) {
        super(what);
    }
}

TVMInstruction fetch(Allocator)(Allocator a, TVMPointer code) {
    if(isNil(code)) return ret();
    // NOTE Assumes that the value returned is actually an instruction.
    else            return asInstruction(peek(a, code));
}

TVMValue peek(Allocator)(Allocator a, TVMPointer stack) {
    if(isPair(stack)) {
        if(!isNil(stack)) {
            return asPair(stack).car;
        } else {
            return value(nil());
        }
    } else {
        throw new RuntimeError("Malformed stack!");
    }
}

TVMPointer pop(Allocator)(Allocator a, TVMPointer stack) {
    if(isPair(stack)) {
        if(!isNil(stack)) {
            auto p = asPair(stack);
            TVMValue rest = p.cdr;

            auto r = use(rest.ptr); // Use the rest of the list.
            free(a, stack);         // Free the pair reference.

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

TVMValue nth(Allocator)(Allocator a, size_t n, TVMPointer stack) {
    if(n == 0)         return peek(a, stack);
    if(isNil(stack))   throw new RuntimeError("Stack overflow!");
    if(!isPair(stack)) throw new RuntimeError("Malformed stack.");
    else {
        TVMValue rest = asPair(stack).cdr;
        return nth(a, n-1, rest.ptr);
    }
}

time_t step(time_t time, TVMContext uProc) {
    auto DEFAULT_DELAY = 0;

    auto instruction = fetch(uProc.alloc, uProc.code);
    auto opcode = instruction.opcode;
    auto argument = instruction.argument;

    debug(verbose) {
        import std.stdio;
        import tvm.compiler.printer;

        writeln(time, " uProc @", uProc, ":");
        writeln(time, " code:   ", codeToString(asPair(uProc.code)));
        writeln(time, " env:    ", print(uProc.env));
        writeln(time, " stack:  ", print(uProc.stack));
        writeln(time, " vstack: ", print(uProc.vstack));
        writeln(time, " instr:  ", print(instruction));
    }

    switch(opcode) {
        case TVMInstruction.PUSH:
            // NOTE No need to free(argument) as the reference is transfered from one stack to the other.
            uProc.vstack = push(uProc.alloc, argument, uProc.vstack);

            // Remove the instruction from the stream.
            uProc.code = pop(uProc.alloc, uProc.code);
            return DEFAULT_DELAY;

        case TVMInstruction.NEXT:
            switch(argument.type) {
                case TVMValue.POINTER:
                    // Make a closure...
                    auto closure = closure(uProc.alloc, use(argument), value(use(uProc.env)));

                    // ...and push it onto the stack....
                    uProc.stack = push(uProc.alloc, value(closure), uProc.stack);

                    // ...and remove the instruction from the stream.
                    uProc.code = pop(uProc.alloc, uProc.code);
                    return DEFAULT_DELAY;

                case TVMValue.INTEGER:
                    // Get the (nth argument uProc.env) closure...
                    auto val = nth(uProc.alloc, argument.integer, uProc.stack);

                    if(!isPointer(val) || isNil(val) || !isClosure(val.ptr))
                        throw new RuntimeError("Bad continuation.");

                    auto closure = use(asClosure(val.ptr));

                    // Push it onto the stack...
                    uProc.stack = push(uProc.alloc, value(closure), uProc.stack);

                    // ...and remove the instruction from the stream.
                    uProc.code = pop(uProc.alloc, uProc.code);
                    return DEFAULT_DELAY;

                default:
                    throw new RuntimeError("Invalid bytecode instruction.");
            }

        case TVMInstruction.TAKE:
            // Take a value from the stack...
            auto val = use(peek(uProc.alloc, uProc.stack));
            uProc.stack = pop(uProc.alloc, uProc.stack);

            // ...push it onto the env...
            uProc.env = push(uProc.alloc, val, uProc.env);

            // ...and remove the instruction from the stream.
            uProc.code = pop(uProc.alloc, uProc.code);
            // NOTE No need to free(argument) as its a plain integer.
            return DEFAULT_DELAY;

        case TVMInstruction.ENTER:
            switch(argument.type) {
                case TVMValue.POINTER:
                    // Enter a piece of code...
                    auto val = use(argument.ptr);
                    free(uProc.alloc, uProc.code);
                    uProc.code = val;

                    // ...and free the argument.
                    free(uProc.alloc, argument.ptr);
                    return DEFAULT_DELAY;

                case TVMValue.INTEGER:
                    // Get the (nth argument uProc.env) closure...
                    auto val = nth(uProc.alloc, argument.integer, uProc.env);

                    if(!isPointer(val) || isNil(val) || !isClosure(val.ptr))
                        throw new RuntimeError("Bad continuation.");

                    auto closure = use(val.ptr);

                    // ...and enter it by substituting current code and env...
                    TVMValue c = use(asClosure(closure).code);
                    free(uProc.alloc, uProc.code);
                    uProc.code = c.ptr;

                    TVMValue e = use(asClosure(closure).env);
                    free(uProc.alloc, uProc.env);
                    uProc.env = e.ptr;

                    // ...and lastly, free the closure object.
                    free(uProc.alloc, val.ptr);
                    return DEFAULT_DELAY;

                default:
                    throw new RuntimeError("Invalid bytecode instruction.");
            }

        case TVMInstruction.PRIMOP:
            // Pop the instruction from the code stack...
            uProc.code = pop(uProc.alloc, uProc.code);

            // ...and pass evaluation to the primitive operator...
            return primopFun(argument.integer)(time, uProc);

        case TVMInstruction.COND:
            // Extract both branches of the conditional...
            auto then = asPair(argument.ptr).car;
            auto else_ = asPair(argument.ptr).cdr;

            // Check if top of the vstack is non-nil and select a branch...
            auto val = peek(uProc.alloc, uProc.vstack);

            TVMValue branch = void;
            if(isNil(val)) branch = use(else_);
            else           branch = use(then);

            // ...free the other branch and enter the closure...
            free(uProc.alloc, argument.ptr);
            argument = branch;
            uProc.vstack = pop(uProc.alloc, uProc.vstack);
            goto case TVMInstruction.ENTER;

        case TVMInstruction.RETURN:
            // Get the closure on top of the stack...
            auto val = peek(uProc.alloc, uProc.stack);

            if(!isPointer(val) || isNil(val) || !isClosure(val.ptr))
                throw new RuntimeError("Bad continuation.");

            auto closure = use(val.ptr);
            uProc.stack = pop(uProc.alloc, uProc.stack);

            // ...and enter it by substituting current code and env...
            TVMValue c = use(asClosure(closure).code);
            free(uProc.alloc, uProc.code);
            uProc.code = c.ptr;

            TVMValue e = use(asClosure(closure).env);
            free(uProc.alloc, uProc.env);
            uProc.env = e.ptr;

            // ...and lastly, free the closure object.
            free(uProc.alloc, val.ptr);
            return DEFAULT_DELAY;

        case TVMInstruction.HALT:
            // FIXME This should halt immediately.
            return TVMMicroProc.MAX_SLEEP_TIME;

        default:
            assert(0, "Bad byte code instruction.");
    }
}


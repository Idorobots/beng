module tvm.vm.interpreter;

import std.typecons;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.bytecode;
import tvm.vm.primops;
import tvm.vm.gc;
import tvm.vm.scheduler;

class RuntimeError : Exception {
    this(string what) {
        super(what);
    }
}

TVMInstructionPtr fetch(Allocator)(Allocator a, TVMPointer code) {
    // NOTE Assumes that the value returned is actually an instruction.
    TVMValue val = peek(a, code);
    return asInstruction(val.ptr);
}

TVMValue peek(Allocator)(Allocator a, TVMPointer stack) {
    if(isNil(stack))  return value(nil());
    if(isPair(stack)) return asPair(stack).car;
    else              throw new RuntimeError("Malformed stack!");
}

TVMPointer pop(Allocator)(Allocator a, TVMPointer stack) {
    if(isPair(stack)) {
        if(!isNil(stack)) {
            auto p = asPair(stack);
            TVMValue rest = p.cdr;

            auto r = use(rest.ptr); // Use the rest of the list.
            //free(a, stack);         // Free the pair reference. // FIXME

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
    if(isNil(stack))   throw new RuntimeError("Stack overflow!");
    if(n == 0)         return peek(a, stack);
    if(!isPair(stack)) throw new RuntimeError("Malformed stack.");
    else {
        TVMValue rest = asPair(stack).cdr;
        return nth(a, n-1, rest.ptr);
    }
}

void fail(string fmt, TVMValue val) {
    throw new RuntimeError(format(fmt, val.type));
}

void fail(TVMInstructionPtr instruction) {
    throw new RuntimeError(format("Invalid bytecode instruction: %s.", instruction.opcode));
}

time_t step(time_t time, TVMContext uProc, ref TVMConfig config) {
    auto DEFAULT_DELAY = 0;

    debug(verbose) {
        import std.stdio;
        import tvm.compiler.printer;

        writeln(time, " uProc @", uProc, ":");
        writeln(time, " code:   ", print(uProc.code));
        writeln(time, " env:    ", print(uProc.env));
        writeln(time, " stack:  ", print(uProc.stack));
        writeln(time, " vstack: ", print(uProc.vstack));
    }

    if(!isNil(uProc.code)) {
        auto instruction = fetch(uProc.alloc, uProc.code);
        auto opcode = instruction.opcode;
        auto addressing = instruction.addressing;
        TVMValue argument = instruction.argument;

        switch(opcode) {
            case TVMInstruction.PUSH:
                // Push argument onto the vstack...
                uProc.vstack = push(uProc.alloc, use(argument), uProc.vstack);

                // ...and remove the instruction from the stream.
                uProc.code = pop(uProc.alloc, uProc.code);
                return DEFAULT_DELAY;

            case TVMInstruction.NEXT:
                switch(addressing) {
                    case TVMInstruction.ADDR_VAL:
                        // Make a self-evaluating closure...
                        auto c = list(uProc.alloc, value(tvm.vm.bytecode.push(uProc.alloc, use(argument))));
                        auto closure = closure(uProc.alloc, value(c), value(use(uProc.env)));

                        // ...and push it onto the stack....
                        uProc.stack = push(uProc.alloc, value(closure), uProc.stack);

                        // ...and remove the instruction from the stream.
                        uProc.code = pop(uProc.alloc, uProc.code);
                        return DEFAULT_DELAY;

                    case TVMInstruction.ADDR_CODE:
                        // Make a closure...
                        auto closure = closure(uProc.alloc, use(argument), value(use(uProc.env)));

                        // ...and push it onto the stack....
                        uProc.stack = push(uProc.alloc, value(closure), uProc.stack);

                        // ...and remove the instruction from the stream.
                        uProc.code = pop(uProc.alloc, uProc.code);
                        return DEFAULT_DELAY;

                    case TVMInstruction.ADDR_ARG:
                        // Get the (nth argument uProc.env) closure...
                        auto val = nth(uProc.alloc, argument.integer, uProc.env);

                        if(!isPointer(val) || isNil(val) || !isClosure(val.ptr))
                            fail("Bad continuation: %s.", val);

                        auto closure = use(asClosure(val.ptr));

                        // Push it onto the stack...
                        uProc.stack = push(uProc.alloc, value(closure), uProc.stack);

                        // ...and remove the instruction from the stream.
                        uProc.code = pop(uProc.alloc, uProc.code);
                        return DEFAULT_DELAY;

                    default:
                        fail(instruction);
                        assert(0);
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
                switch(addressing) {
                    case TVMInstruction.ADDR_CODE:
                        // Enter a piece of code...
                        auto val = use(argument.ptr);
                        free(uProc.alloc, uProc.code);
                        uProc.code = val;

                        // ...and free the argument.
                        free(uProc.alloc, argument.ptr);
                        return DEFAULT_DELAY;

                    case TVMInstruction.ADDR_ARG:
                        // Get the (nth argument uProc.env) closure...
                        auto val = nth(uProc.alloc, argument.integer, uProc.env);

                        if(!isPointer(val) || isNil(val) || !isClosure(val.ptr))
                            fail("Bad continuation: %s.", val);

                        auto closure = use(val.ptr);

                        // ...and enter it by substituting current code and env...
                        TVMValue c = use(asClosure(closure).code);
                        free(uProc.alloc, uProc.code);
                        uProc.code = c.ptr;

                        TVMValue e = use(asClosure(closure).env);
                        free(uProc.alloc, uProc.env);
                        uProc.env = e.ptr;

                        // ...and lastly, free the closure object.
                        free(uProc.alloc, closure);
                        return DEFAULT_DELAY;

                    default:
                        fail(instruction);
                        assert(0);
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

                // ...and enter the closure...
                argument = branch;
                uProc.vstack = pop(uProc.alloc, uProc.vstack);

                addressing = TVMInstruction.ADDR_CODE;
                goto case TVMInstruction.ENTER;

            case TVMInstruction.SPAWN:
                // Create a new uProc...
                auto up = new shared TVMMicroProc(config.uProcHeapSize,
                                                  config.uProcMSGqSize,
                                                  cast(ubyte) config.uProcDefaultPriority,
                                                  time);

                // ...setup its environment...
                auto val = peek(uProc.alloc, uProc.vstack);

                auto a = up.alloc;
                auto cont = closure(a,
                                    value(list(a, value(tvm.vm.bytecode.push(a, use(val))))),
                                    value(use(uProc.env)));
                auto halt = closure(a, value(list(a, value(halt(a)))), value(use(uProc.env)));

                up.code = list(a,value(enter(arg(), a, argument.integer)));
                up.env = use(uProc.env);
                up.stack = list(a, value(cont), value(halt));

                // ...and run it...
                runProc(asMicroProc(use(up)), config);
                uProc.vstack = pop(uProc.alloc, uProc.vstack);
                uProc.vstack = push(uProc.alloc, value(use(up)), uProc.vstack);

                // ...lastly, pop the instruction from the code stack.
                uProc.code = pop(uProc.alloc, uProc.code);
                return DEFAULT_DELAY;

            case TVMInstruction.HALT:
                // FIXME This should halt immediately.
                return TVMMicroProc.MAX_SLEEP_TIME;

            default:
                fail(instruction);
                assert(0);
        }
    } else {
        // NOTE This executes the TVMInstruction.RETURN instruction.

        // Get the closure on top of the stack...
        auto val = peek(uProc.alloc, uProc.stack);

        if(!isPointer(val) || isNil(val) || !isClosure(val.ptr))
            fail("Bad continuation: %s.", val);

        auto closure = asClosure(val.ptr);

        // ...and enter it by substituting current code and env...
        TVMValue c = use(closure.code);
        free(uProc.alloc, uProc.code);
        uProc.code = c.ptr;

        TVMValue e = use(closure.env);
        free(uProc.alloc, uProc.env);
        uProc.env = e.ptr;

        // ...and lastly, free the closure object.
        uProc.stack = pop(uProc.alloc, uProc.stack);
        return DEFAULT_DELAY;
    }
}

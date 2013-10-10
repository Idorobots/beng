module compiler.pretty.print;

import std.string;
import eval.gc.memory;
import eval.vm.state;


string toString(SimpleValue that) {
    return format("[0x%x|0x%x]([0x%x|0x%x|0x%x])",
                  that.tag,
                  that.value,
                  that.opcode,
                  that.operand.tag,
                  that.operand.value);
}

string toString(ObjectHeader that) {
    return format("[%d|0x%x|0x%x]", that.refCount, that.tag, that.history);
}

string toString(ref Cons that) {
    return format("%s {\nCar: %s\nCdr: %s\n}",
                  that.header.toString(),
                  that.car.toString(),
                  that.cdr.toString());
}

string toString(ref VmState that) {
    return format("%s {\nCode: %s\nStck: %s\nEnv:  %s\nCont: %s\n}",
                  that.header.toString(),
                  that.code.toString(),
                  that.stack.toString(),
                  that.environment.toString(),
                  that.continuation.toString());
}


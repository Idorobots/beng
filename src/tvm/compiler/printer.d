module tvm.compiler.printer;

import std.string : format;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;

string toString(TVMContext c) {
    return format("#%d{%d}", c.priority, c.asleep ? c.wakeTime : c.vRunTime);
}

string toString(TVMValue v) {
    return "";
}

string toString(TVMPointer v) {
    return "";
}

string print(B)(B bytecode) {
    // TODO Implement same bytecode disassembly.
    return "";
}
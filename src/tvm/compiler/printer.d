module tvm.compiler.printer;

import std.string : format;

import tvm.compiler.ast;
import tvm.vm.objects;
import tvm.vm.bytecode;

string toString(TVMContext c) {
    return format("#%d{%d}", c.priority, c.asleep ? c.wakeTime : c.vRunTime);
}

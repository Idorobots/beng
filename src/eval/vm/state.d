module eval.vm.state;

import std.string;
import eval.gc.memory;

struct VmState {
    ObjectHeader header;
    SimpleValue code;
    SimpleValue stack;
    SimpleValue environment;
    SimpleValue continuation;
}

VmState mkState(void* code, void* stack, void* env, void* cont) {
    VmState vm;
    vm.header = mkHeader(0b101, null);
    vm.code = mkSimple(code);
    vm.stack = mkSimple(stack);
    vm.environment = mkSimple(env);
    vm.continuation = mkSimple(cont);
    return vm;
}
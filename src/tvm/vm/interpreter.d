module tvm.vm.interpreter;

import tvm.vm.utils;
import tvm.vm.objects;
import tvm.vm.bytecode;

time_t step(time_t time, TVMContext uProc) {
    // TODO Actually implement this.

    TVMValue v = void;
    if(uProc.msgq.dequeue(v)) {
        debug(verbose) {
            import std.stdio;
            writeln(currentTime(), " uProc #", uProc.priority, " got a message...");
        }

        auto otherUProc = (cast(TVMContext) v.rawPtr);

        // Send your own pid.
        v.rawPtr = cast(TVMPointer) uProc;
        otherUProc.msgq.enqueue(v);
    }

    return time + 100_000;
}


module main;

import std.stdio;
import eval.gc.memory;
import eval.vm.state;
import compiler.pretty.print;

void main() {
    auto v = mkFloat(23.5);
    auto i = mkInstruction(0x42, v);
    auto o = mkHeader(0b111, &i);
    auto nil = mkCons(mkSimple(null), mkSimple(null));
    auto one = mkCons(v, mkSimple(&nil));
    auto two = mkCons(v, mkSimple(&one));
    auto code = mkCons(i, mkSimple(&nil));
    auto vm = mkState(&code, &two, &one, &nil);

    writeln("Float: ", v.toString() );
    writeln("Instruction: ", i.toString());
    writeln("Header: ", o.toString());
    writeln("List: ", two.toString(), one.toString(), nil.toString());
    writeln("State: ", vm.toString());
}
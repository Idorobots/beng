module main;

import std.stdio;
import std.file;
import std.string;

import compiler.parser.ast;
import compiler.parser.scanner;
import compiler.parser.parse;
import compiler.codegen.compile;
import eval.vm.run;
import compiler.pretty.print;
import compiler.pretty.graph;

void main(string[] args) {
    if (args.length > 2) {
        auto file = args[2];
        auto source = readText(file);

        try {
            switch (args[1]) {
                case "parse":
                    foreach(expr; parse(source)) {
                        writeln(expr);
                    }
                    break;

                case "compile":
                    print(compile(parse(source)));
                    break;

                case "run":
                    print(run(compile(parse(source))));
                    break;

                case "graph":
                    graph(run(compile(parse(source))));
                    break;

                default:
                    break;
            }
        } catch (SyntaxError e) {
            handle(file, source, e);
        } catch (SemanticError e) {
            handle(file, source, e);
        } catch (Exception e) {
            writeln(e.msg);
        }
    }
}

void handle(string name, string source, SyntaxError e) {
    auto token = e.token;
    auto preamble = format("%s(%d, %d): ", name, token.line+1, token.column);

    writeln(preamble, "Syntax Error: ", e.msg, "\n");

    foreach(i; 0 .. preamble.length) write(" ");
    foreach(i; 0 .. source.length - token.offset - token.column) {
        auto c = source[token.offset - token.column + i];
        write(c);
        if(c == '\n') break;
    }

    foreach(i; 0 .. preamble.length + token.column)
        write(" ");
    write("^");

    if(token.value.length > 0)
        foreach(i; 0 .. token.value.length - 1)
            write("~");
    writeln("\n");
}

void handle(string name, string source, SemanticError e) {
    writeln(name, ": Semantic Error: ", e.msg);
}
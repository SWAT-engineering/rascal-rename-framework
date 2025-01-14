@license{
Copyright (c) 2018-2023, NWO-I CWI and Swat.engineering
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
}
@bootstrapParser
module refactor::Rename

extend refactor::TextEdits;

extend Message;
import util::Reflective;

data TModel;
data Tree;

data RenameState;

alias RenameResult = tuple[list[DocumentEdit], map[str, ChangeAnnotation], set[Message]];

data RenameSolver(
        RenameResult() run = RenameResult() { fail; }
      , void(loc l, void(RenameState, Tree, RenameSolver) doWork, RenameState state) collectParseTree = void(loc _, void(RenameState, Tree, RenameSolver) _, RenameState _) { fail; }
      , void(loc l, void(RenameState, TModel, RenameSolver) doWork, RenameState state) collectTModel = void(loc _, void(RenameState, TModel, RenameSolver) _, RenameState _) { fail; }
      , void(Message) msg = void(Message _) { fail; }
      , void(DocumentEdit) documentEdit = void(DocumentEdit _) { fail; }
      , void(TextEdit) textEdit = void(TextEdit _) { fail; }
      , void(str, ChangeAnnotation) annotation = void(str _, ChangeAnnotation _) { fail; }
      , value(str) readStore = value(str _) { fail; }
      , void(str, value) writeStore = void(str _, value _) { fail; }
) = rsolver();

data RenameConfig
    = rconfig(
        Tree(loc) parseLoc
      , TModel(loc) tmodelForLoc
    );

@example{
    Consumer implements something like:
    ```
    alias RenameRequest = tuple[list[Tree] cursorFocus, str newName];

    public tuple[list[DocumentEdit], map[str, ChangeAnnotation], set[Message] msgs] rename(RenameRequest request) {
        RenameConfig config = rconfig(parseFunc, typeCheckFunc);
        RenameSolver solver = newSolverForConfig(config);
        initSolver(solver, config, request);
        return solver.run();
    }
    ```
}
RenameSolver newSolverForConfig(RenameConfig config) {
    RenameSolver solver = rsolver();
    // COLLECT

    // TODO Batch & cache parse operations
    // lrel[loc file, void(RenameState, Tree, RenameSolver) work] treeTasks = [];
    solver.collectParseTree = void(loc l, void(RenameState, Tree, RenameSolver) doWork, RenameState state) {
        Tree t = config.parseLoc(l);
        doWork(state, t, solver);
    };

    solver.collectTModel = void(loc l, void(RenameState, TModel, RenameSolver) doWork, RenameState state) {
        // TODO Batch & cache TC operations
        TModel tm = config.tmodelForLoc(l);
        doWork(state, tm, solver);
    };

    // REGISTER
    set[Message] messages = {};
    solver.msg = void(Message msg) {
        messages += msg;
    };

    lrel[loc file, DocumentEdit edit] docEdits = [];
    solver.documentEdit = void(DocumentEdit edit) {
        loc f = edit has file ? edit.file : edit.from;
        // TODO Implement merging with existing doc edit
        docEdits += <f, edit>;
    };

    solver.textEdit = void(TextEdit edit) {
        loc f = edit.range.top;
        // TODO Implement merging with exiting doc edit
        docEdits += <f, changed(f, [edit])>;
    };

    map[str id, ChangeAnnotation annotation] annotations = ();
    solver.annotation = void(str annotationId, ChangeAnnotation annotation) {
        if (annotationId in annotations) throw "An annotation with id \'<annotationId>\' already exists!";
        annotations[annotationId] = annotation;
    };

    // STORE
    map[str, value] store = ();
    solver.readStore = value(str key) { return store[key]; };
    solver.writeStore = void(str key, value val) {
        store[key] = val;
    };

    // RUN
    solver.run = RenameResult() {
        // Merge document edits
        return <docEdits.edit, annotations, messages>;
    };

    return solver;
}

@license{
Copyright (c) 2024-2025, Swat.engineering
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

import refactor::TextEdits;

import Message;
import util::Reflective;

import IO;
import List;
import Node;

data TModel;
data Tree;

data RenameState;

alias RenameResult = tuple[list[DocumentEdit], map[str, ChangeAnnotation], set[Message]];

data RenameSolver(
        RenameResult() run = RenameResult() { throw "Not implemented"; }
      , void(loc l, void(RenameState, Tree, RenameSolver) doWork, RenameState state) collectParseTree = void(loc _, void(RenameState, Tree, RenameSolver) _, RenameState _) { throw "Not implemented!"; }
      , void(loc l, void(RenameState, TModel, RenameSolver) doWork, RenameState state) collectTModel = void(loc _, void(RenameState, TModel, RenameSolver) _, RenameState _) { throw "Not implemented!"; }
      , void(Message) msg = void(Message _) { throw "Not implemented"; }
      , void(DocumentEdit) documentEdit = void(DocumentEdit _) { throw "Not implemented"; }
      , void(TextEdit) textEdit = void(TextEdit _) { throw "Not implemented"; }
      , void(str, ChangeAnnotation) annotation = void(str _, ChangeAnnotation _) { throw "Not implemented"; }
      , value(str) readStore = value(str _) { throw "Not implemented"; }
      , void(str, value) writeStore = void(str _, value _) { throw "Not implemented"; }
) = rsolver();

data RenameConfig
    = rconfig(
        Tree(loc) parseLoc
      , TModel(loc) tmodelForLoc
      , bool reportCollectCycles = false
      , bool debug = true
    );

alias TreeTask = tuple[loc file, void(RenameState, Tree, RenameSolver) work, RenameState state];
alias ModelTask = tuple[loc file, void(RenameState, TModel, RenameSolver) work, RenameState state];

str describeState(RenameState s) = "<getName(s)>#<arity(s)>";

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
    list[TreeTask] treeTaskQueue = [];
    list[tuple[loc, RenameState]] treeTasksDone = [];
    solver.collectParseTree = void(loc l, void(RenameState, Tree, RenameSolver) doWork, RenameState state) {
        if (<l, state> notin treeTasksDone) {
            treeTaskQueue += <l, doWork, state>;
            treeTasksDone += <l, state>;
        } else if (config.reportCollectCycles) {
            println("-- Cycle detected: skipping parse tree collection for <describeState(state)> (<l>)");
        }
    };

    list[ModelTask] modelTaskQueue = [];
    list[tuple[loc, RenameState]] modelTasksDone = [];
    solver.collectTModel = void(loc l, void(RenameState, TModel, RenameSolver) doWork, RenameState state) {
        if (<l, state> notin modelTasksDone) {
            modelTaskQueue += <l, doWork, state>;
            modelTasksDone += <l, state>;
        } else if (config.reportCollectCycles) {
            println("-- Cycle detected: skipping TModel collection for <describeState(state)> (<l>)");
        }
    };

    // REGISTER
    set[Message] messages = {};
    solver.msg = void(Message msg) {
        messages += msg;
    };

    lrel[loc file, DocumentEdit edit] docEdits = [];
    solver.documentEdit = void(DocumentEdit edit) {
        loc f = edit has file ? edit.file : edit.from;
        docEdits += <f, edit>;
    };

    solver.textEdit = void(TextEdit edit) {
        loc f = edit.range.top;
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
    map[loc, Tree] treeCache = ();
    map[loc, TModel] modelCache = ();

    Tree getTree(loc l) {
        if (l notin treeCache) {
            treeCache[l] = config.parseLoc(l);
        } else if (config.debug) {
            println("-- Using cached tree for <l>");
        }
        return treeCache[l];
    }

    TModel getTModel(loc l) {
        if (l notin modelCache) {
            modelCache[l] = config.tmodelForLoc(l);
        } else if (config.debug) {
            println("-- Using cached TModel for <l>");
        }
        return modelCache[l];
    }

    solver.run = RenameResult() {
        while (treeTaskQueue != [] || modelTaskQueue != []) {
            treeTaskQueueCopy = treeTaskQueue;
            modelTaskQueueCopy = modelTaskQueue;

            // We will do all tasks in the queue
            treeTaskQueue = [];
            modelTaskQueue = [];

            for (loc f <- treeTaskQueueCopy.file + modelTaskQueueCopy.file) {
                fileTreeTasks = treeTaskQueueCopy[f];
                if (config.debug) println("<size(fileTreeTasks)> tasks for tree of <f>");

                Tree tree = getTree(f);
                for (<treeWork, state> <- treeTaskQueueCopy[f]) {
                    treeWork(state, tree, solver);
                }

                fileModelTasks = modelTaskQueueCopy[f];
                if (config.debug) println("<size(fileModelTasks)> tasks for model of <f>");

                TModel model = getTModel(f);
                for (<modelWork, state> <- modelTaskQueueCopy[f]) {
                    modelWork(state, model, solver);
                }
            }
        }

        // Merge document edits
        return <mergeTextEdits(docEdits.edit), annotations, messages>;
    };

    return solver;
}

list[DocumentEdit] mergeTextEdits(list[DocumentEdit] edits) {
    // Only merge subqequent text edits to the same file.
    // Leave all other edits in the order in which they were registered
    list[DocumentEdit] mergedEdits = [];
    loc runningFile = |unknown:///|;
    list[TextEdit] runningEdits = [];

    void batchRunningEdits(loc thisFile) {
        if (runningEdits != []) {
            mergedEdits += changed(runningFile, runningEdits);
        }
        runningFile = thisFile;
        runningEdits = [];
    }

    for (DocumentEdit e <- edits) {
        loc thisFile = e has file ? e.file : e.from;
        if (thisFile != runningFile) {
            batchRunningEdits(thisFile);
        }

        if (e is changed) {
            runningEdits += e.edits;
        } else {
            batchRunningEdits(thisFile);
            mergedEdits += e;
        }
    }

    batchRunningEdits(|unknown:///|);

    return mergedEdits;
}

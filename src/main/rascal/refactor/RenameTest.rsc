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
module refactor::RenameTest

import refactor::Rename;

test bool mergeNoTextEdits() =
    mergeTextEdits([]) == [];

test bool mergeTextEditsToSingleFile() =
    mergeTextEdits([
        changed(|memory:///file1|, [replace(|memory:///file1|(0, 0, <0, 0>, <0, 0>), "")])
      , changed(|memory:///file1|, [replace(|memory:///file1|(1, 0, <0, 0>, <0, 0>), "")])
      , changed(|memory:///file1|, [replace(|memory:///file1|(2, 0, <0, 0>, <0, 0>), "")])
    ]) == [
        changed(|memory:///file1|, [
            replace(|memory:///file1|(0, 0, <0, 0>, <0, 0>), "")
          , replace(|memory:///file1|(1, 0, <0, 0>, <0, 0>), "")
          , replace(|memory:///file1|(2, 0, <0, 0>, <0, 0>), "")
        ])
    ];

test bool mergeTextEditsWithRenameInBetween() =
    mergeTextEdits([
        changed(|memory:///file1|, [replace(|memory:///file1|(0, 0, <0, 0>, <0, 0>), "")])
      , changed(|memory:///file1|, [replace(|memory:///file1|(1, 0, <0, 0>, <0, 0>), "")])
      , renamed(|memory:///file1|, |memory:///file2|)
      , changed(|memory:///file1|, [replace(|memory:///file1|(2, 0, <0, 0>, <0, 0>), "")])
    ]) == [
        changed(|memory:///file1|, [
            replace(|memory:///file1|(0, 0, <0, 0>, <0, 0>), "")
          , replace(|memory:///file1|(1, 0, <0, 0>, <0, 0>), "")
        ])
      , renamed(|memory:///file1|, |memory:///file2|)
      , changed(|memory:///file1|, [
            replace(|memory:///file1|(2, 0, <0, 0>, <0, 0>), "")
        ])
    ];

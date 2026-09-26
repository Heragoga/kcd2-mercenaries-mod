# Movie

C++ class(es): `CScriptBindMovie`, `CScriptBind_Movie`
Reached from Lua as `Movie.FunctionName(...)`.
9 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AbortSequence

```lua
Movie.AbortSequence(sSequenceName)
```

Aborts the specified sequence.

Abort a sequence @param pszName Name of sequence

| Param | Description |
|---|---|
| const char* sSequenceName | Sequence name. |

docs: y · retail: confirmed (binary, runtime dump)

### GetMemoryUsage

```lua
Movie.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Movie.

docs: y · retail: unconfirmed

### IsPlaying

```lua
Movie.IsPlaying(const char *sSequenceName)
```

Checks if the specified sequence is currently playing.

| Param | Description |
|---|---|
| const char * sSequenceName | Sequence name. |

docs: y · retail: unconfirmed

### PauseSequences

```lua
Movie.PauseSequences()
```

C++: `int PauseSequences (IFunctionHandler * pH )`

Pauses all the sequences.

docs: y · retail: confirmed (runtime dump)

### PlaySequence

```lua
Movie.PlaySequence(sSequenceName)
```

Plays the specified sequence.

Start a sequence @param pszName Name of sequence

| Param | Description |
|---|---|
| const char * sSequenceName | Sequence name. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Triggers/AreaTrigger.lua`))

### ResumeSequences

```lua
Movie.ResumeSequences()
```

C++: `int ResumeSequences (IFunctionHandler * pH )`

Resume all the sequences.

docs: y · retail: confirmed (runtime dump)

### StopAllCutScenes

```lua
Movie.StopAllCutScenes()
```

C++: `int StopAllCutScenes (IFunctionHandler * pH )`

Stops all the cut scenes.

docs: y · retail: confirmed (runtime dump)

### StopAllSequences

```lua
Movie.StopAllSequences()
```

C++: `int StopAllSequences (IFunctionHandler * pH )`

Stops all the video sequences.

docs: y · retail: confirmed (runtime dump)

### StopSequence

```lua
Movie.StopSequence(sSequenceName)
```

Stops the specified sequence.

Stop a sequence @param pszName Name of sequence

| Param | Description |
|---|---|
| const char* sSequenceName | Sequence name. |

docs: y · retail: confirmed (binary, runtime dump)

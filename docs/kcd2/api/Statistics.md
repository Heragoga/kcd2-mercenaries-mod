# Statistics

C++ class(es): `C_ScriptBindStatistics`
Reached from Lua as `Statistics.FunctionName(...)`.
2 documented function(s); 3 additional undocumented function(s) found in retail/runtime.

## Functions

### Increment

```lua
Statistics.Increment(const char* statisticName, int value)
```

Sets a statistics counter to a specific value.

| Param | Description |
|---|---|
| const char* statisticName | name of the statistic in the database |
| int value | integer value to set |

docs: y · retail: confirmed (binary, runtime dump)

### Reset

```lua
Statistics.Reset(const char* statisticName)
```

Resets a statistics counter.

| Param | Description |
|---|---|
| const char* statisticName | name of the statistic in the database |

docs: y · retail: confirmed (binary, runtime dump, vanilla×81)

## Undocumented (present in retail, not in official docs)

### Insert

`Statistics.Insert(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### Remove

`Statistics.Remove(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### Set

`Statistics.Set(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

# Database

C++ class(es): `C_ScriptBindDatabase`
Reached from Lua as `Database.FunctionName(...)`.
5 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### GetColumnInfo

```lua
Database.GetColumnInfo("weapons", 2)
```

Returns lua table with description of one column.

| Param | Description |
|---|---|
| char const* tableName | name of the table |
| int columnIdx | index of column |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DatabaseUtils.lua`))

### GetTableColumnData

```lua
Database.GetTableColumnData("weapons", 2)
```

Returns lua table with members of one table column

| Param | Description |
|---|---|
| char const* tableName | name of the table |
| int columnIdx | index of column |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DatabaseUtils.lua`))

### GetTableInfo

```lua
Database.GetTableInfo("weapons")
```

Returns lua table with C_Table properties.

| Param | Description |
|---|---|
| char const* tableName | name of the table |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DatabaseUtils.lua`))

### GetTableLine

```lua
Database.GetTableLine("weapons", 5)
```

Returns lua table with members of one data line.

| Param | Description |
|---|---|
| char const* tableName | name of the table |
| C_TableBase | :T_LineIdx lineIdx index of line |

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DatabaseUtils.lua`))

### LoadTable

```lua
Database.LoadTable("weapons")
```

Loads or reloads table. Returns true if table is loaded.

| Param | Description |
|---|---|
| char const* tableName | name of the table |

docs: y · retail: confirmed (binary, runtime dump)

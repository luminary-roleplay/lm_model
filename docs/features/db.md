# Feature: db

Automatically persists records to a MySQL database via **oxmysql**. The feature hooks into `create` and `delete` to run INSERT / soft-delete queries immediately, and flushes dirty records on a background timer.

## Manifest setup

```lua
-- fxmanifest.lua
dependency 'lm_model'
```

`oxmysql` must be running when you use this feature. Load the module in Lua with `local Db = require('@lm_model.imports.db')`.

---

## Configuration

```lua
features = {
    db = {
        -- Path to a .sql file loaded from the current resource.
        -- SELECT  – used by dbLoad() to populate the store on startup.
        selectAll = 'queries/vehicles/select_all.sql',

        -- INSERT  – used by create(). Receives the serialized record data.
        insert    = 'queries/vehicles/insert.sql',

        -- UPDATE  – used by flushRecord(). Receives the serialized dirty record.
        update    = 'queries/vehicles/update.sql',

        -- DELETE  – used by delete(). Receives { [primaryKey] = id }.
        delete    = 'queries/vehicles/delete.sql',

        -- Load all rows into memory when the store is created. Default: true.
        autoLoad = true,

        -- Start a background thread that flushes dirty records on an interval. Default: true.
        autoBatch = true,

        -- Milliseconds between batch flushes. Default: 5000.
        batchInterval = 5000,
    },
}
```

All SQL path fields are optional. Omit `insert` to skip DB writes on create (useful when IDs are pre-assigned outside the model). Omit `update` to skip dirty flushing.

---

## SQL file conventions

SQL files are loaded with `LoadResourceFile` from the owning resource. Use `?` placeholders compatible with oxmysql.

**select_all.sql**
```sql
SELECT id, plate, owner, color FROM vehicles
```

**insert.sql**
```sql
INSERT INTO vehicles (plate, owner, color)
VALUES (@plate, @owner, @color)
```

**update.sql**
```sql
UPDATE vehicles
SET plate = @plate, owner = @owner, color = @color, version = @version
WHERE id = @id
```

**delete.sql** *(soft delete example)*
```sql
UPDATE vehicles SET deleted_at = NOW() WHERE id = @id
```

The parameters passed to insert/update come from `config.serialize(record.data)`. The parameter passed to delete is `{ [primaryKey] = id }`.

---

## Auto-increment primary keys

When `insert` is configured and the record's primary key field is `nil` at create time, the feature assigns the returned auto-increment ID automatically:

```lua
local record = store:create({ plate = 'ABC123', owner = 'steam:...' })
-- record.id is now the MySQL auto-increment value
print(record.id)
```

---

## `parse` and `serialize` lifecycle

```
DB row  ──parse()──▶  record.data  ──serialize()──▶  DB write
```

Use `parse` to transform raw DB column types (e.g. convert JSON strings, `TINYINT(1)` booleans):

```lua
parse = function(row)
    row.metadata = json.decode(row.metadata) or {}
    return row
end,

serialize = function(data)
    return {
        id       = data.id,
        plate    = data.plate,
        owner    = data.owner,
        metadata = json.encode(data.metadata),
    }
end,
```

---

## Methods added by this feature

```lua
-- Load all rows from the DB into memory (re-runs the selectAll query).
store:dbLoad()

-- Flush one dirty record to the DB immediately.
store:flushRecord(record, context?)

-- Flush all queued dirty records. Returns number flushed.
store:flushDirty(context?)
```

`flushDirty` is called automatically by the batch thread unless `autoBatch = false`.

---

## DB Adapter (`imports/db.lua`)

The feature uses the shared DB adapter internally. You can import it directly in any server script for raw queries outside a model:

```lua
local Db = require('@lm_model.imports.db')

-- Inline queries
local rows   = Db.query('SELECT * FROM vehicles WHERE owner = ?', { steam })
local row    = Db.single('SELECT * FROM vehicles WHERE id = ?', { id })
local scalar = Db.scalar('SELECT COUNT(*) FROM vehicles')
local newId  = Db.insert('INSERT INTO vehicles (plate) VALUES (?)', { 'XYZ' })
local rows   = Db.update('UPDATE vehicles SET plate = ? WHERE id = ?', { 'NEW', id })
Db.execute('DELETE FROM vehicles WHERE id = ?', { id })

-- SQL file queries (loaded from the calling resource)
local rows = Db.queryFile('queries/my_query.sql', { ... })
local row  = Db.singleFile('queries/my_single.sql', { id = 1 })

-- Transactions
Db.transaction({ 'UPDATE ...', 'UPDATE ...' })
```

All methods are synchronous (use `await` internally) and safe to call at the top level of a Citizen thread or callback.

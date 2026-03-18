# lm_model

A standalone, modular data-model library for FiveM. It provides a structured, server-authoritative store of typed records with optional persistence, cross-resource synchronisation, and client mirroring — all wired together through a central registry.

## Requirements

| Requirement | Required |
|---|---|
| `ox_lib` | Yes |
| `oxmysql` | Must be running when using the `db` feature |

## Installation

Add `lm_model` to your resource manifest **before** the resource that consumes it:

```lua
-- fxmanifest.lua (consuming resource)
dependency 'lm_model'
```

Then load modules directly in your Lua code via `require(...)`, for example:

```lua
local Model = require('@lm_model.imports.model')
local Db = require('@lm_model.imports.db')
local ClientModel = require('@lm_model.client.model')
```

## Core Concepts

```
┌────────────────────────────────────────────────────────┐
│  lm_model (registry)                                   │
│  Tracks: name → { owner, eventName, features }        │
└────────────────────────────────────────────────────────┘
         ▲                              ▲
         │ registerModelOwner           │ getModelDefinition
         │                              │
┌────────┴──────────┐       ┌──────────┴──────────────┐
│  Owner resource   │       │  Consumer resource       │
│  Model.register() │       │  RemoteModel.connect()   │
│  BaseStore        │──────▶│  RemoteConnection        │
│  ModelRecord      │ sync  │  (mirror + proxy)        │
└───────────────────┘       └─────────────────────────-┘
         │ TriggerClientEvent
         ▼
┌─────────────────────────┐
│  Client resource        │
│  ClientModel.connect()  │
│  ClientModelConnection  │
└─────────────────────────┘
```

**BaseStore** — Lives in the owning server resource. Holds all `ModelRecord` instances in memory, fires local change events, and drives optional features.

**ModelRecord** — A single item inside a store. Separates *persisted data* (written to DB, synced) from *runtime state* (in-memory only, also synced).

**Registry** — A small global service running inside `lm_model` itself. Every store that calls `Model.register()` advertises its name, owner, and feature flags so other resources can discover it.

**Features** — Opt-in capabilities attached to a store at creation time:

| Feature | Summary |
|---|---|
| [`db`](docs/features/db.md) | Persist records to MySQL via oxmysql |
| [`sync`](docs/features/sync.md) | Broadcast changes to server resources and/or clients |
| [`subscriptions`](docs/features/subscriptions.md) | Per-player and/or per-resource subscription targeting |
| [`invoker`](docs/features/invoker.md) | Expose store/record methods as exports to other server resources |
| [`client_requests`](docs/features/client-requests.md) | Let clients call store/record methods over net events (rate-limited) |

## Quick Example

```lua
-- server/vehicles.lua  (owner resource)
local Model = require('@lm_model.imports.model')

local Vehicles = Model.register({
    name       = 'vehicles',
    eventName  = 'vehicles',
    primaryKey = 'id',

    parse     = function(row) return row end,
    serialize = function(data) return data end,
    public    = function(record) return { id = record.id, plate = record:get('plate') } end,

    features = {
        db = {
            selectAll = 'queries/vehicles/select_all.sql',
            update    = 'queries/vehicles/update.sql',
        },
        sync          = { clients = true },
        subscriptions = true,
        invoker = {
            allowedStoreMethods  = { lock = true, unlock = true },
            allowedRecordMethods = { setPlate = true },
        },
        client_requests = {
            allowedStoreMethods  = {},
            allowedRecordMethods = {},
        },
    },
})
```

```lua
-- client/vehicles.lua
local ClientModel = require('@lm_model.client.model')

local vehicles = ClientModel.connect({ model = 'vehicles' })

-- vehicles:get(id)      → public payload table
-- vehicles:getAll()     → table<id, payload>
-- vehicles:resync()     → reload full snapshot from server
```

## Documentation

- [Features Overview](docs/features.md) — High-level guide to feature roles and common stacks
- [Server Model](docs/server-model.md) — `BaseStore`, `ModelRecord`, hooks, `define` vs `register`
- [Hooks](docs/hooks.md) — Lifecycle hook reference, return semantics, and examples
- [Client Model](docs/client-model.md) — `ClientModel.connect`, mirroring, client requests
- [Remote Model](docs/remote-model.md) — Server-to-server proxy and mirror via `RemoteModel.connect`
- [Client State](docs/client-state.md) — Pure client-side local state (no server involvement)
- **Features**
  - [db](docs/features/db.md)
  - [sync](docs/features/sync.md)
  - [subscriptions](docs/features/subscriptions.md)
  - [invoker](docs/features/invoker.md)
  - [client-requests](docs/features/client-requests.md)

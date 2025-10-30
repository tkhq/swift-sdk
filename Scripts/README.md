# Code Generation

Code generation is handled by custom Swift executables in this directory. See details below.

## Usage

```bash
make generate
```

That's it! This generates types, clients, and formats everything.

## What Gets Generated

- **Types**: `Sources/TurnkeyTypes/Generated/Types.swift`
- **Clients**: 
  - `Sources/TurnkeyHttp/Public/TurnkeyClient+Public.swift`
  - `Sources/TurnkeyHttp/Public/TurnkeyClient+AuthProxy.swift`

## ⚠️ When to Update Constants

When syncing from the monorepo, update `Scripts/Sources/Internal/Constants.swift` if:
- An activity type version changed (e.g., `V2` → `V3`)
- A new activity was created with all optional parameters

Then run `make generate` to regenerate code.

## Structure

```
Scripts/
├── Sources/
│   ├── Internal/
│   │   ├── Constants.swift              # Config constants
│   │   └── Resources/                   # Swagger specs
│   ├── Typegen/main.swift              # Type generator
│   └── Clientgen/main.swift            # Client generator
└── Package.swift                        # Swift package config
```

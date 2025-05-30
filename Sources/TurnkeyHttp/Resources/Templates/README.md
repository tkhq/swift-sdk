# Stencil Templates

This document explains how we use [Sourcery](https://github.com/krzysztofzablocki/Sourcery) and [Stencil](https://stencil.fuller.li) templates to generate Swift code in the Turnkey SDK.

---

## What is Stencil?

 [Stencil](https://stencil.fuller.li/) is a Swift-based templating language inspired by Django and Jinja. It’s commonly used for generating code. When combined with [Sourcery](https://github.com/krzysztofzablocki/Sourcery), it can introspect your Swift types and auto-generate boilerplate code based on customizable templates.

## What We Use It For

We use Stencil and Sourcery to generate our `TurnkeyClient.swift`, which provides typed methods for interacting with the Turnkey API. This prevents us from having to hand-write dozens of repetitive request wrappers.

## Template Files

The templates live in `Resources/Templates`. There are two main files:

* `TurnkeyClient.stencil`: The primary template that renders the full client file.
* `macros.stencil`: A collection of reusable helper macros used by `TurnkeyClient.stencil`.

## How It Works

1. `swift-openapi-generator` creates all the base request/response types under `Generated/`.
2. Sourcery reads those types and passes them into the Stencil templates.
3. `TurnkeyClient.stencil` uses logic and macros to emit Swift methods.
4. The result is saved to `Public/TurnkeyClient.swift`.

To trigger this process, run:

```bash
make turnkey_client
```

---

## Macro Overview (`macros.stencil`)

Each macro is a reusable logic block that simplifies the generation process.

### `addMethodParams`

Generates Swift method parameters based on a `Request` struct.

```stencil
foo: String, bar: Int
```

### `addRequestBody`

Constructs an instance of a `Request` struct from the method parameters.

```swift
MyRequest(foo: foo, bar: bar)
```

### `addActivityMethodParams`

Special logic for activity requests. It flattens parameters inside a nested `parameters` object, and skips `_type` and `timestampMs`.

### `getActivityType`

Looks up the first enum case value for `_type` inside the request struct.

```swift
.typeName
```

### `getIntentParams`

Generates Swift-style initializers for a Turnkey "intent" object (used inside activity requests).

### `generateActivityMethod`

Composes an entire method including:

* Creating the intent struct
* Creating the request struct
* Constructing the operation input
* Making the API call

---

## Template Flow

In `TurnkeyClient.stencil`, we:

1. Import `macros.stencil`:

```stencil
{% import "macros.stencil" %}
```

2. Loop through every API method:

```stencil
{% for method in class.instanceMethods %}
```

3. If it's an activity request (contains `_type`), we call:

```stencil
{% call generateActivityMethod method.callName %}
```

4. Otherwise, we:

* Use `addMethodParams` to generate parameters
* Construct a request struct
* Call the endpoint
* Handle responses

---

## Powered By StencilSwiftKit

We use [StencilSwiftKit](https://github.com/SwiftGen/StencilSwiftKit), a powerful Stencil extension that adds filters and tags tailored for Swift code generation.

---

## Sourcery Stencil Templates Overview

### Templates in the Project

The project uses [Sourcery](https://krzysztofzablocki.github.io/Sourcery/) with Stencil templates to automate code generation for the Turnkey SDK. The specific template used is `TurnkeyClient.stencil`, located in the `@templates` folder.

### How the Templates are Used

Sourcery leverages the `TurnkeyClient.stencil` template to generate Swift code based on the types defined in the `Sources/TurnkeySDK/Generated` directory. The output of this process is a Swift file named `TurnkeyClient.generated.swift`, which is placed in the `Sources/TurnkeySDK` directory.

### Running the Templates with Sourcery

The process of running Sourcery with the Stencil templates is integrated into the project's `Makefile`. Here's how the templates are run:

1. **Generate Command**: This is the main command that triggers the entire generation process, including running Sourcery.

   ```Makefile
   generate: generate
   ```

2. **Sourcery Command**: This specific command runs Sourcery using the `TurnkeyClient.stencil` template.

   ```Makefile
   turnkey_client:
       sourcery --sources Sources/TurnkeySDK/Generated \
       --output Sources/TurnkeySDK/TurnkeyClient.generated.swift \
       --templates TurnkeyClient.stencil \
       $(if $(WATCH),--watch,)
   ```

   - `--sources`: Specifies the directory containing the source files that Sourcery will scan.
   - `--output`: Specifies where the generated Swift file will be placed.
   - `--templates`: Points to the Stencil template file.
   - `--watch`: An optional flag that, if set, makes Sourcery watch the source and template directories for changes and regenerate the output automatically.

### Explanation of `macros.stencil`

The `macros.stencil` file defines several macros that are reusable pieces of template code used to generate Swift code dynamically based on the types and methods defined in the Sourcery scanned data. Here's a breakdown of each macro:

1. **[addMethodParams](/templates/macros.stencil#2%2C10-2%2C10)**:

   - Generates method parameters for a given method name by matching structs whose names, when "Request" is removed, match the method name.
   - It iterates over the methods of these structs and outputs each parameter's name and type, formatting the type by removing the "Swift." prefix.

2. **[addRequestBody](/templates/macros.stencil#12%2C10-12%2C10)**:

   - Similar to [addMethodParams](/templates/macros.stencil#2%2C10-2%2C10), but instead of just listing parameters, it constructs an instance of the struct with parameters passed to it.

3. **[addActivityMethodParams](/templates/macros.stencil#23%2C10-23%2C10)**:

   - This macro is specialized for activity methods, excluding parameters named "\_type" and "timestampMs".
   - If the parameter is named "parameters", it maps the variables of the parameter's type into a list of parameters.

4. **[getActivityType](/templates/macros.stencil#37%2C10-37%2C10)**:

   - Retrieves the type of activity from a method by finding the "\_type" parameter and returning its value.

5. **[getIntentParams](/templates/macros.stencil#47%2C10-47%2C10)**:

   - Generates a list of parameters for a given intent struct name by mapping the struct's variables into a format suitable for initializing an instance of the struct.

6. **[generateActivityMethod](/templates/macros.stencil#54%2C10-54%2C10)**:
   - This is a comprehensive macro that generates a complete method for activity handling.
   - It sets up the request and intent structures, prepares the input for the method call, and finally makes the call using the underlying client.

### Usage in `TurnkeyClient.stencil`

In the `TurnkeyClient.stencil` file, these macros are imported and used to generate methods within the [TurnkeyClient](/Makefile#12%2C30-12%2C30) struct. Here's how they are utilized:

- **Importing Macros**: At the beginning of the `TurnkeyClient.stencil`, macros from `macros.stencil` are imported.

  ```stencil
  {% import "macros.stencil" %}
  ```

- **Using Macros in Method Generation**:
  - For each method in classes implementing `APIProtocol`, the template checks if it's an activity request (by checking if the method's parameters include "\_type").
  - Depending on whether it's an activity request or a regular request, it either calls `generateActivityMethod` or uses `addMethodParams` to generate the method signature and body.
  - For activity requests, `generateActivityMethod` is called, which internally uses other macros like `addActivityMethodParams`, `getActivityType`, and `getIntentParams` to generate a complete method.
  - For regular requests, `addMethodParams` is used to generate the method parameters, and the method body is constructed inline in the `TurnkeyClient.stencil`.

### StencilSwiftKit and Macro Usage

[`StencilSwiftKit`](https://github.com/SwiftGen/StencilSwiftKit) is an extension to Stencil that provides additional tags and filters useful for Swift code generation. In the context of these templates:

- Macros are defined using `{% macro macroName %}` and called using `{% call macroName %}`.
- The use of macros helps in reusing template code and keeping the `TurnkeyClient.stencil` file cleaner and more maintainable by abstracting complex logic into the `macros.stencil` file.

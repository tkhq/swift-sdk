# swift-sdk

## Getting Started

This guide will help you set up your development environment for the Turnkey SDK, which leverages tools like Sourcery for code generation and Swift OpenAPI Generator for working with OpenAPI specifications.

### Installation of Necessary Tools

1. **Sourcery**:

   - Used for code generation.
   - Install via Homebrew:
     ```bash
     brew install sourcery
     ```
   - [More about installing Sourcery](https://krzysztofzablocki.github.io/Sourcery/installing.html).

2. **swift-format**:
   - Used for formatting Swift code.
   - Install via Homebrew:
     ```bash
     brew install swift-format
     ```

### Editing Templates and Regenerating Code

To modify the code generation templates and regenerate the code:

1. Navigate to the `@templates` directory.
2. Edit the `TurnkeyClient.stencil` or any other Stencil template files as needed.
3. Run the following command to regenerate the code:
   ```bash
   make generate
   ```
   This command will use Sourcery to apply your changes in the templates to generate the Swift code accordingly.

### Running Tests

To run the tests, you need to set up the environment variables first:

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
2. Open the `.env` file and populate it with the necessary keys and values as required for your testing environment.

3. To execute the tests, use the following command:
   ```bash
   make test
   ```
   This command cleans any previous builds, sets up the environment, and runs the tests defined in the project.

## Tools Overview

### Sourcery

[Sourcery](https://github.com/krzysztofzablocki/Sourcery) automates the boilerplate code in Swift projects. It scans your source code, applies your personal templates, and generates Swift code for you, allowing you to use meta-programming techniques like macros in Swift.

### Swift OpenAPI Generator

[Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) is a tool that generates Swift client and server code from an OpenAPI document. It supports OpenAPI versions 3.0 and 3.1 and generates code that is compatible with various Apple platforms including macOS, iOS, and watchOS.

## Project Structure

The Turnkey SDK project is structured into several key directories:

- **Sources/TurnkeySDK**: Contains the source files for the SDK.
- **Sources/TurnkeySDK/Generated**: This directory is used to store auto-generated Swift files. It is populated by running the `swift-openapi-generator`.
- **@templates**: Holds the Stencil templates used by Sourcery for code generation. The main template is `TurnkeyClient.stencil`.

## Makefile Commands

The project uses a `Makefile` to simplify the execution of common tasks:

- **generate**: Runs all necessary commands to generate code, clean up, and format the code.
  ```bash
  make generate
  ```
- **turnkey_client_types**: Generates Swift types from OpenAPI specifications.
  ```bash
  make turnkey_client_types
  ```
- **turnkey_client**: Generates Swift client code using Sourcery and the specified Stencil template.
  ```bash
  make turnkey_client
  ```
- **clean**: Removes generated files to ensure a clean state.
  ```bash
  make clean
  ```
- **test**: Runs tests after cleaning up generated files.
  ```bash
  make test
  ```
- **format**: Formats the Swift code in the project.
  ```bash
  make format
  ```

## Contributing

Contributors are encouraged to familiarize themselves with the project structure and `Makefile` commands. When contributing code, ensure to run `make format` to keep the codebase consistent. For major changes, please open an issue first to discuss what you would like to change.

## License

Please ensure to review the project's license as specified in the LICENSE file.

This README provides a comprehensive guide to setting up and understanding the Turnkey SDK project. For any additional questions or issues, please refer to the project's issue tracker or contact the maintainers.

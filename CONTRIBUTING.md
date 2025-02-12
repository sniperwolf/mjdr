# Contributing to MJDR

First off, thank you for considering contributing to MJDR! It's people like you that make MJDR such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to
uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When
you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps which reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include details about your configuration and environment

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful

### Pull Requests

* Fill in the required template
* Follow the Shell Style Guide
* Run ShellCheck on all shell scripts
* Include comments in your code where necessary
* Update documentation if needed
* End all files with a newline

## Shell Style Guide

* Use ShellCheck and fix all warnings
* Use 4 spaces for indentation
* Use double quotes for strings containing variables
* Use meaningful variable names
* Add comments for complex operations
* Keep functions focused and small
* Use local variables in functions
* Always check for errors and handle them appropriately

## Development Process

1. Fork the repo
2. Create a new branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run ShellCheck on all shell scripts
5. Test your changes
6. Commit your changes (`git commit -am 'Add new feature'`)
7. Push to the branch (`git push origin feature/my-feature`)
8. Create a Pull Request

## Setting Up Development Environment

1. Install required tools:
    * Git
    * Docker
    * ShellCheck
    * Your favorite text editor with shell script support

2. Clone the repository:

```bash
   git clone https://github.com/sniperwolf/mjdr.git
   cd mjdr
```

3. Make scripts executable:

```bash
   chmod +x *.sh
   chmod +x libs/*.sh
```

4. Set up your environment:

```bash
   cp .env.example .env
# Edit .env with your configuration
```

## Running Tests

Currently, we rely on ShellCheck for static analysis:

```bash
shellcheck libs/*.sh *.sh
```

## Documentation

* Comment your code
* Update README.md if needed
* Add notes about significant changes to CHANGELOG.md
* Update examples if you change interfaces

## Questions?

Feel free to open an issue with your question.

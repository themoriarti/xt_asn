# Contributing to xt_asn

Thank you for your interest in contributing to the xt_asn project! This document provides guidelines and information for contributors.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Environment](#development-environment)
4. [Coding Standards](#coding-standards)
5. [Testing](#testing)
6. [Submitting Changes](#submitting-changes)
7. [Issue Reporting](#issue-reporting)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Getting Started

### Prerequisites

- Linux system with kernel 3.7+
- gcc compiler
- autotools (autoconf, automake, libtool)
- iptables development headers
- Git

### Setting up Development Environment

1. **Fork the repository** on GitHub
2. **Clone your fork**:
   ```bash
   git clone https://github.com/yourusername/xt_asn.git
   cd xt_asn
   ```

3. **Install dependencies** (Ubuntu/Debian):
   ```bash
   sudo apt-get install build-essential autoconf automake libtool \
       pkg-config iptables-dev libxtables-dev linux-headers-$(uname -r)
   ```

4. **Build the project**:
   ```bash
   ./autogen.sh
   ./configure --enable-debug --enable-testing
   make
   ```

5. **Run tests**:
   ```bash
   make check
   ```

## Development Environment

### Building with Different Systems

**Autotools (Traditional):**
```bash
./autogen.sh
./configure --enable-debug
make
```

**CMake (Modern):**
```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug -DENABLE_TESTING=ON
make
```

### Debugging

Enable debug mode during configuration:
```bash
./configure --enable-debug
```

This adds debug symbols and enables debug logging in the kernel module.

## Coding Standards

### C Code Style

We follow the Linux kernel coding style with these specifics:

- **Indentation**: 8-character tabs
- **Line length**: 80 characters maximum
- **Braces**: K&R style
- **Naming**: lowercase with underscores
- **Comments**: /* C-style comments */

Use the provided `.clang-format` file:
```bash
clang-format -i extensions/*.c extensions/*.h
```

### Shell Scripts

- Use `#!/bin/bash` shebang
- 4-space indentation
- Quote variables: `"$variable"`
- Use `set -e` for error handling
- Validate with shellcheck

### Perl Scripts

- Use strict and warnings
- 4-space indentation
- Follow Perl Best Practices

## Testing

### Running Tests

**All tests:**
```bash
make check
```

**Specific test categories:**
```bash
cd tests
./test_userspace.sh      # Userspace library tests
./test_integration.sh    # Integration tests (requires root)
./test_asn_data.sh       # ASN data processing tests
```

### Writing Tests

When adding new features:

1. **Add unit tests** for userspace code
2. **Add integration tests** for kernel module functionality
3. **Add data tests** for ASN processing changes
4. **Update existing tests** if modifying behavior

Test files should:
- Be executable (`chmod +x`)
- Include descriptive test names
- Provide clear pass/fail output
- Clean up after themselves

### Test Requirements

- Tests should not require internet access during CI
- Root permissions should only be needed for integration tests
- All tests should pass before submitting PRs

## Submitting Changes

### Pull Request Process

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following coding standards

3. **Add tests** for new functionality

4. **Test your changes**:
   ```bash
   make check
   ./tests/test_integration.sh  # If you have root access
   ```

5. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request** on GitHub

### Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Keep first line under 50 characters
- Add detailed description if needed
- Reference issues: "Fixes #123" or "Closes #456"

Example:
```
Add support for IPv6 ASN filtering

- Implement IPv6 address parsing in userspace library
- Add binary search for IPv6 ranges in kernel module
- Update tests to cover IPv6 functionality
- Update documentation with IPv6 examples

Fixes #42
```

### Code Review Process

All submissions require review. We use GitHub pull requests for this purpose. Reviewers will check for:

- Code quality and style
- Test coverage
- Documentation updates
- Backwards compatibility
- Security implications

## Issue Reporting

### Bug Reports

Include the following information:

1. **System Information**:
   - OS and version
   - Kernel version (`uname -r`)
   - iptables version
   - xt_asn version

2. **Steps to Reproduce**:
   - Exact commands used
   - Configuration files
   - iptables rules

3. **Expected vs Actual Behavior**

4. **Logs and Error Messages**:
   - dmesg output
   - iptables errors
   - Application logs

### Feature Requests

When requesting features:

1. **Describe the use case** clearly
2. **Explain the problem** it solves
3. **Suggest implementation** if you have ideas
4. **Consider backwards compatibility**

### Security Issues

For security-related issues:

1. **Do not** open a public issue
2. **Email** maintainers directly
3. **Provide** detailed information
4. **Allow time** for investigation

## Development Guidelines

### Architecture

- **Kernel module** (`xt_asn.c`): Core filtering logic
- **Userspace library** (`libxt_asn.c`): iptables integration
- **Data processing** (`asn/`): BGP data handling
- **Tests** (`tests/`): Validation and verification

### Adding New Features

1. **Design first**: Consider architecture impact
2. **Start small**: Implement minimal viable version
3. **Test thoroughly**: Unit, integration, and manual tests
4. **Document**: Update README and man pages
5. **Consider compatibility**: Don't break existing functionality

### Performance Considerations

- Keep kernel code minimal and efficient
- Use appropriate data structures (binary search for ranges)
- Consider memory usage in kernel space
- Profile performance-critical paths

### Security Considerations

- Validate all user input
- Handle kernel memory carefully
- Avoid information leaks
- Follow principle of least privilege

## Documentation

### Required Documentation Updates

When making changes, update:

- README.md for user-facing changes
- INSTALL.md for installation changes
- Man pages for option changes
- Code comments for implementation details

### Documentation Style

- Use clear, concise language
- Include examples
- Test all commands and examples
- Keep formatting consistent

## Release Process

Releases follow semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

The release process:

1. Update version numbers
2. Update changelog
3. Create release tag
4. Build packages
5. Upload artifacts
6. Announce release

## Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **IRC**: #netfilter on irc.freenode.net
- **Mailing List**: netfilter-devel@vger.kernel.org

## License

By contributing to this project, you agree that your contributions will be licensed under the GNU General Public License v2.0.

---

Thank you for contributing to xt_asn! Your efforts help make network security better for everyone.

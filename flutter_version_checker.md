# Flutter Version Checker & Auto-Increment Action

A GitHub Action that automatically checks Flutter version numbers in `pubspec.yaml` against branch history and auto-increments them if needed. This action ensures that each build has a unique, incrementally increasing version number.

## Features

- **🔍 Version History Check**: Scans branch commit history to find previous versions
- **📈 Auto-Increment**: Automatically increments patch and build numbers when needed
- **🧠 Smart Comparison**: Handles semantic versioning with build numbers (e.g., `50.8.47+177`)
- **🚀 Auto-Commit**: Commits and pushes version changes automatically with tags
- **📊 Detailed Outputs**: Provides previous, current, and new version information
- **⚙️ Flexible Configuration**: Customizable branch, pubspec path, and commit messages
- **🔒 Secure**: Uses GitHub token authentication for safe operations
- **🏷️ Git Tags**: Automatically creates version tags for releases

## How It Works

1. **Fetches History**: The action fetches the specified branch history
2. **Finds Previous Version**: Scans recent commits to find the last version in `pubspec.yaml`
3. **Compares Versions**: Uses semantic versioning to compare current vs previous
4. **Auto-Increments**: If current ≤ previous, automatically increments the version
5. **Commits Changes**: Pushes the updated `pubspec.yaml` with a descriptive commit
6. **Creates Tags**: Adds version tags for easy release tracking
7. **Continues Workflow**: Your CI/CD continues with the corrected version

## Usage

### Basic Usage

```yaml
name: Flutter Version Check and Auto-Increment

on:
  push:
    branches: [ main, release/*, develop ]

jobs:
  version-check:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        token: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Check and Auto-Increment Flutter Version
      id: version-check
      uses: Abdo-ka/flutter-version-checker@v2.4.2
      with:
        branch: ${{ github.ref_name }}
        token: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Continue with your CI/CD
      run: |
        echo "Version: ${{ steps.version-check.outputs.current-version }}"
        echo "Was updated: ${{ steps.version-check.outputs.version-updated }}"
        # Your Flutter build, test, and deployment steps here
```

### Advanced Usage

```yaml
- name: Check and Auto-Increment Flutter Version
  id: version-check
  uses: Abdo-ka/flutter-version-checker@v1
  with:
    branch: 'release/production'
    token: ${{ secrets.GITHUB_TOKEN }}
    commit-message: 'Auto-increment version to %NEW_VERSION% [skip ci]'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `branch` | The branch to check version history against | Yes | `main` |
| `token` | GitHub token for pushing changes | Yes | `${{ github.token }}` |
| `commit-message` | Custom commit message for version updates | No | `Auto-increment version` |

## Outputs

| Output | Description |
|--------|-------------|
| `previous-version` | The previous version found in branch history |
| `current-version` | The current version after processing |
| `version-updated` | Whether the version was automatically updated (`true`/`false`) |
| `new-version` | The new version if updated |

## Version Format

This action supports Flutter's standard version format:

```
major.minor.patch+build
```

Examples:
- `1.0.0+1`
- `50.8.47+177`
- `2.1.5+42`

## How It Works

1. **Read Current Version**: Extracts version from `pubspec.yaml` in project root
2. **Fetch Branch History**: Retrieves commit history for the specified branch
3. **Find Previous Version**: Scans commits to find the most recent different version
4. **Compare Versions**: Uses semantic versioning comparison with build number support
5. **Auto-Increment**: If current ≤ previous, increments patch and build numbers
6. **Update & Commit**: Updates `pubspec.yaml`, commits the change, and creates a version tag
7. **Continue CI/CD**: Allows the workflow to continue with the correct version

## Version Increment Logic

When a version needs to be incremented:

- **Previous**: `50.8.47+177`
- **Current**: `50.8.47+177` (same or lower)
- **New**: `50.8.48+178`

The action increments:
- Patch version by 1
- Build number by 1

## Example Scenarios

### Scenario 1: Version Already Incremented
```
Previous: 1.0.0+5
Current:  1.0.1+6
Result:   No change needed
```

### Scenario 2: Same Version (Auto-increment)
```
Previous: 1.0.0+5
Current:  1.0.0+5
Result:   Updated to 1.0.1+6
```

### Scenario 3: Lower Version (Auto-increment)
```
Previous: 1.0.5+10
Current:  1.0.3+8
Result:   Updated to 1.0.6+11
```

## Tag-Based Version Bump Tool

In addition to the GitHub Action, this repository includes a powerful **local tag-based version bump tool** that you can use for manual version management:

### Quick Start

```bash
# Preview what would happen
./scripts/bump-version.sh --dry-run

# Auto-bump version based on latest tag
./scripts/bump-version.sh

# Bump specific version type
./scripts/bump-version.sh --bump-type patch

# Bump and create tag
./scripts/bump-version.sh --bump-type minor --create-tag
```

### Features

- 🏷️ **Tag-Aware**: Compares current version with latest git tag
- 🤖 **Smart Bumping**: Auto-determines appropriate version bump type
- 🔧 **Multiple Bump Types**: Support for major, minor, patch, and build increments
- 🔍 **Dry Run Mode**: Preview changes before applying them
- 📦 **Auto-Tagging**: Optionally create and push git tags
- ✅ **Validation**: Verifies version changes and provides clear feedback

### Available Commands

```bash
# Show help
./scripts/bump-version.sh --help

# Run examples with explanations
./scripts/examples.sh

# Different bump types
./scripts/bump-version.sh --bump-type major    # 1.0.3+5 → 2.0.0+1
./scripts/bump-version.sh --bump-type minor    # 1.0.3+5 → 1.1.0+1
./scripts/bump-version.sh --bump-type patch    # 1.0.3+5 → 1.0.4+1
./scripts/bump-version.sh --bump-type build    # 1.0.3+5 → 1.0.3+6

# Force bump even if current version is ahead
./scripts/bump-version.sh --force --bump-type patch
```

For detailed documentation, see [TAG_BASED_VERSION_BUMP.md](TAG_BASED_VERSION_BUMP.md).

## Local Development

### Setup

```bash
# Clone the repository
git clone https://github.com/Abdo-ka/flutter-version-checker.git
cd flutter-version-checker

# Install dependencies
npm install

# Run tests
npm test

# Build the action
npm run build
```

### Testing

The action includes comprehensive tests for version parsing, comparison, and increment logic:

```bash
npm test
```

## Requirements

- Node.js 20+
- Git repository with commit history
- `pubspec.yaml` file in repository root with version field
- GitHub token with repository write permissions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run `npm test` and `npm run build`
6. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

If you encounter issues or have questions:

1. Check the [GitHub Issues](https://github.com/Abdo-ka/flutter-version-checker/issues)
2. Create a new issue with detailed information
3. Include your workflow file and error messages

## Local Auto-Increment (No Token Required!)

### Quick Start

For local development or CI environments where you don't want to use GitHub tokens:

```bash
# Using npm script (easiest)
npm run version:increment

# Using the script directly
node scripts/auto-increment-version.js

# Using the interactive helper
./scripts/increment.sh
```

### Features

- ✅ **No GitHub token required** - uses your existing git authentication
- ✅ **Simple one-command execution**
- ✅ **Automatic version increment** (patch + build number)
- ✅ **Git commit and push** with descriptive message
- ✅ **Version tag creation** (e.g., `v1.0.2+3`)
- ✅ **Works locally and in CI/CD**

### Setup

1. **Install dependencies** (if not already done):
   ```bash
   npm install js-yaml
   ```

2. **Configure git** (one-time setup):
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

3. **Run the script**:
   ```bash
   npm run version:increment
   ```

### Example Output

```
🚀 Flutter Version Auto-Increment Script
=========================================
📦 Current version: 1.0.1+2
📈 New version: 1.0.2+3
✅ Updated pubspec.yaml with version: 1.0.2+3
📝 Staging changes...
💾 Committing changes...
🏷️  Creating tag v1.0.2+3...
🚀 Pushing changes...
🚀 Pushing tag...
🎉 Version successfully incremented and pushed!
```

### GitHub Actions (Auto-Increment Only)

Use the simplified workflow for automatic version increment:

```yaml
name: Auto-Increment Version

on:
  push:
    branches: [ main, develop ]

permissions:
  contents: write

jobs:
  auto-increment-version:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0
        token: ${{ github.token }}
    
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
    
    - run: npm ci
    - run: npm run version:increment
```

See [AUTO_INCREMENT_GUIDE.md](AUTO_INCREMENT_GUIDE.md) for detailed documentation.

## GitHub Action Usage (Published)

### Quick Setup for Your Flutter Project

Add this workflow to your Flutter repository at `.github/workflows/version-check.yml`:

```yaml
name: Flutter Version Auto-Increment

on:
  push:
    branches: [ main, develop ]

permissions:
  contents: write  # Required for pushing version updates

jobs:
  version-check:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        token: ${{ github.token }}
    
    - name: Auto-Increment Flutter Version
      uses: Abdo-ka/flutter-version-checker@v1
      with:
        branch: ${{ github.ref_name }}
        token: ${{ github.token }}
        commit-message: "🚀 Auto-increment version [skip ci]"
    
    # Continue with your Flutter build steps...
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: 'stable'
    
    - name: Build App
      run: |
        flutter pub get
        flutter build apk
```

### Advanced Usage

```yaml
- name: Check and Auto-Increment Flutter Version
  id: version-check
  uses: Abdo-ka/flutter-version-checker@v1
  with:
    branch: 'main'
    token: ${{ github.token }}
    commit-message: 'Auto-increment version to %NEW_VERSION% [skip ci]'

- name: Use Version Info
  run: |
    echo "Previous: ${{ steps.version-check.outputs.previous-version }}"
    echo "Current: ${{ steps.version-check.outputs.current-version }}"
    echo "Updated: ${{ steps.version-check.outputs.version-updated }}"
```

See [examples/github-workflows.md](examples/github-workflows.md) for more usage examples.

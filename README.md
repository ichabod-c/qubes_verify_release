# Qubes OS Release Verification Script

This repository provides a Bash script to securely verify signatures of Qubes OS release files, following the official guidelines: [https://www.qubes-os.org/security/verifying-signatures/](https://www.qubes-os.org/security/verifying-signatures/)

## Overview

The `qubes_verify_release.sh` script automates the following steps:

1. Import and authenticate the Qubes Master Signing Key (QMSK)
2. Set the QMSK trust level to `ultimate`
3. Import the Release Signing Key (RSK) from a URL or local file
4. Verify the signature of the release file

It supports both interactive (default) and non-interactive (CI/CD) modes, color-coded output, and robust error checks.

## Prerequisites

* GNU/Linux with Bash ≥ 4.x
* `gpg2` (GnuPG 2.x)
* Internet access for key retrieval (unless using a local RSK file)

## Usage

```bash
./qubes_verify_release.sh [options]
```

### Options

| Option                      | Description                                                 |
| --------------------------- | ----------------------------------------------------------- |
| `-f, --file PATH`           | Release file to verify (e.g., `Qubes-R4.1.0.iso`)           |
| `-s, --sig PATH`            | Corresponding signature file (e.g., `Qubes-R4.1.0.iso.asc`) |
| `-v, --version X.Y`         | Qubes OS version (for automatic RSK retrieval)              |
| `-k, --rsk-key PATH or URL` | Local file or URL of the Release Signing Key (RSK)          |
| `-n, --non-interactive`     | Non-interactive mode (automatic trust and imports)          |
| `-h, --help`                | Display this help message                                   |

### Examples

#### 1. Interactive mode

```bash
./qubes_verify_release.sh \
  -f Qubes-R4.1.0-x86_64.iso \
  -s Qubes-R4.1.0-x86_64.iso.asc \
  -v 4.1.0
```

The script will prompt to confirm trust for the QMSK.

#### 2. Non-interactive mode (CI/CD)

```bash
./qubes_verify_release.sh \
  -f Qubes-R4.1.0-x86_64.iso \
  -s Qubes-R4.1.0-x86_64.iso.asc \
  -v 4.1.0 \
  -n
```

Ideal for CI/CD pipelines: trust is set automatically.

#### 3. Using a local RSK file

```bash
./qubes_verify_release.sh \
  -f Qubes-R4.1.0-x86_64.iso \
  -s Qubes-R4.1.0-x86_64.iso.asc \
  -k /path/to/qubes-release-4.1-signing-key.asc
```

## Security Considerations

* **QMSK Fingerprint**: Always verify it matches `427F11FD0FAA4B080123F01CDDFA1A3E36879494`.
* **Keyserver**: The script uses `gpg2 --fetch-keys` from the official Qubes URL.
* **Isolation**: Uses a temporary GNUPGHOME to avoid contaminating your local keyring.


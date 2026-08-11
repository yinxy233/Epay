#!/bin/sh
# Detect the request-header trigger and secret-leaking response logic reported in
# issue #21. This check is intentionally dependency-free so it can run before a
# deployment even when PHP and Composer are unavailable on the operator's host.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
COMPOSER_BOOTSTRAP_DIR="$REPOSITORY_ROOT/includes/vendor/composer"
PLATFORM_CHECK_FILE="$COMPOSER_BOOTSTRAP_DIR/platform_check.php"
AUTOLOAD_REAL_FILE="$COMPOSER_BOOTSTRAP_DIR/autoload_real.php"

# These indicators are not part of Composer's generated bootstrap. A match means
# the bundled dependency loader may again be deriving behavior from an untrusted
# request header or returning the application's signing secret as a session ID.
INDICATORS='HTTP_PHP_VERSION|SERVER_PHP_VERSION|SENTENCEIA|Set-Cookie:[[:space:]]*PHPSESSID'

# Missing bootstrap files are also unsafe because the scan cannot establish that
# the deployed dependency loader is complete and clean.
for BOOTSTRAP_FILE in "$PLATFORM_CHECK_FILE" "$AUTOLOAD_REAL_FILE"; do
    if [ ! -r "$BOOTSTRAP_FILE" ]; then
        echo "Composer bootstrap file is missing or unreadable: $BOOTSTRAP_FILE" >&2
        exit 1
    fi
done

if grep -En "$INDICATORS" "$PLATFORM_CHECK_FILE" "$AUTOLOAD_REAL_FILE"; then
    echo "Unsafe code found in the Composer bootstrap." >&2
    exit 1
else
    GREP_STATUS=$?
    if [ "$GREP_STATUS" -ne 1 ]; then
        echo "Unable to scan the Composer bootstrap." >&2
        exit "$GREP_STATUS"
    fi
fi

echo "Composer bootstrap security check passed."

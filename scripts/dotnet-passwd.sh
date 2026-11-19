# Sourced helper for running the .NET SDK image as a non-root host uid.
# shellcheck shell=sh
#
# mcr.microsoft.com/dotnet/sdk:8.0-alpine (8.0.428 / Alpine 3.24 and later) fails
# on first run with
#   System.IO.IOException: The system cannot open the device or file specified. : 'NuGet-Migrations'
# when the container uid (docker run --user) has no /etc/passwd entry.
# Bind-mount the file this writes over /etc/passwd:
#   -v "$(dotnet_passwd_file)":/etc/passwd:ro

# dotnet_passwd_file [PATH] -> writes a minimal passwd (root + current uid) and
# prints its path. Without PATH a temp file is created; the caller removes it.
dotnet_passwd_file() {
    if [ -n "${1:-}" ]; then
        _pw="$1"
    else
        _pw="$(mktemp "${TMPDIR:-/tmp}/wildling-passwd.XXXXXX")"
    fi
    _pw_uid="$(id -u)"
    {
        echo "root:x:0:0:root:/root:/sbin/nologin"
        if [ "${_pw_uid}" != 0 ]; then
            echo "builder:x:${_pw_uid}:$(id -g)::/tmp:/sbin/nologin"
        fi
    } > "${_pw}"
    chmod 644 "${_pw}"
    echo "${_pw}"
}

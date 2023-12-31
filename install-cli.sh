#!/bin/bash
set -e

CLI_URL="https://app-updates.agilebits.com/product_history/CLI2"

# Fetch the latest version of 1Password CLI (on stable or beta channel)
get_latest_cli_version() {
    conditional_path="/beta/"
    if [ "$1" == "non_beta" ]; then
        conditional_path="!/beta/"
    fi
    # This long command parses the HTML page at "CLI_URL" and finds the latest CLI version
    # based on the release channel we're looking for (stable or beta).
    #
    # The ideal call (i.e. 'curl https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/Y -s | jq -r .version')
    # doesn't retrieve the latest CLI version on a channel basis.
    # If the latest release is stable and we want the latest beta, this command will return the stable still.
    OP_CLI_VERSION="v$(curl -s $CLI_URL | awk -v RS='<h3>|</h3>' 'NR % 2 == 0 {gsub(/[[:blank:]]+/, ""); gsub(/<span[^>]*>|<\/span>|[\r\n]+/, ""); gsub(/&nbsp;.*$/, ""); if (!'"$1"' && '"$conditional_path"'){print; '"$1"'=1;}}')"
}

# Install op-cli
install_op_cli() {
    OP_INSTALL_DIR="$(mktemp -d)"
    if [[ ! -d "$OP_INSTALL_DIR" ]]; then
        echo "Install dir $OP_INSTALL_DIR not found"
        exit 1
    fi
    echo "::debug::OP_INSTALL_DIR: ${OP_INSTALL_DIR}"

    echo "Installing 1Password CLI version: ${OP_CLI_VERSION}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Get architecture
        ARCH=$(uname -m)
        if [[ "$(getconf LONG_BIT)" = 32 ]]; then
            ARCH="386"
        elif [[ "$ARCH" == "x86_64" ]]; then
            ARCH="amd64"
        elif [[ "$ARCH" == "aarch64" ]]; then
            ARCH="arm64"
        fi

        curl -sSfLo op.zip "https://cache.agilebits.com/dist/1P/op2/pkg/${OP_CLI_VERSION}/op_linux_${ARCH}_${OP_CLI_VERSION}.zip"
        unzip -od "$OP_INSTALL_DIR" op.zip && rm op.zip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        curl -sSfLo op.pkg "https://cache.agilebits.com/dist/1P/op2/pkg/${OP_CLI_VERSION}/op_apple_universal_${OP_CLI_VERSION}.pkg"
        pkgutil --expand op.pkg temp-pkg
        tar -xvf temp-pkg/op.pkg/Payload -C "$OP_INSTALL_DIR"
        rm -rf temp-pkg && rm op.pkg
    else
        echo "Install 1Password CLI GitHub Action isn't supported on this operating system yet: $OSTYPE."
        exit 1
    fi
    echo "$OP_INSTALL_DIR" >> "$GITHUB_PATH"
}

# Main action of the script

if [[ "$OP_CLI_VERSION" == "latest" ]]; then
    get_latest_cli_version non_beta
elif [[ "$OP_CLI_VERSION" == "latest-beta" ]]; then
    get_latest_cli_version beta
else
    OP_CLI_VERSION="v$OP_CLI_VERSION"
fi

install_op_cli

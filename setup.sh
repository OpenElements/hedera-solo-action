#!/bin/bash

# Install JSON-RPC-Relay if requested
if [ "$INPUT_INSTALLRELAY" = "true" ]; then
  echo "Installing JSON-RPC-Relay..."
  solo relay deploy
  if [ $? -ne 0 ]; then
    echo "Failed to install JSON-RPC-Relay"
    exit 1
  fi
  echo "JSON-RPC-Relay installed successfully"
fi

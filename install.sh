#!/bin/bash
set -e

swift build -c release
sudo cp .build/release/yoink /usr/local/bin/yoink
echo "Installed yoink to /usr/local/bin/yoink"

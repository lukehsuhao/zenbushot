#!/bin/bash
pkill -f "ZenbuShot" 2>/dev/null
sleep 0.5
open /Applications/ZenbuShot.app
echo "ZenbuShot restarted."

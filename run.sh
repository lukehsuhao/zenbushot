#!/bin/bash
pkill -f "AnyShot" 2>/dev/null
sleep 0.5
open /Applications/AnyShot.app
echo "AnyShot restarted."

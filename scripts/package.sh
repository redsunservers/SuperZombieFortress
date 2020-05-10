# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs
mkdir -p package/addons/sourcemod/gamedata

# Copy all required stuffs to package
cp -r addons/sourcemod/plugins/superzombiefortress.smx package/addons/sourcemod/plugins
cp -r ../addons/sourcemod/configs/szf package/addons/sourcemod/configs
cp -r ../addons/sourcemod/gamedata/szf.txt package/addons/sourcemod/gamedata
cp -r ../addons/sourcemod/translations package/addons/sourcemod
cp -r ../materials package
cp -r ../models package
cp -r ../sound package
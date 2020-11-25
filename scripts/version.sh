# Go to build scripting folder with superzombiefortress.sp
cd build/addons/sourcemod/scripting

# Get plugin version
export PLUGIN_VERSION=$(sed -En '/#define PLUGIN_VERSION\W/p' superzombiefortress.sp)
echo "PLUGIN_VERSION=(echo $PLUGIN_VERSION | grep -o '[0-9]*\.[0-9]*\.[0-9]*')" >> $GITHUB_ENV

# Get revision
export PLUGIN_VERSION_REVISION=$(git rev-list --count HEAD)
echo "PLUGIN_VERSION_REVISION=(git rev-list --count HEAD)" >> $GITHUB_ENV

# Set revision to superzombiefortress.sp
sed -i -e 's/#define PLUGIN_VERSION_REVISION.*".*"/#define PLUGIN_VERSION_REVISION "'$PLUGIN_VERSION_REVISION'"/g' superzombiefortress.sp
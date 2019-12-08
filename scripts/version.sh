# Go to build scripting folder with superzombiefortress.sp
cd build/addons/sourcemod/scripting

# Get plugin version
export PLUGIN_VERSION=$(sed -En '/#define PLUGIN_VERSION\W/p' superzombiefortress.sp)
echo ::set-env name=PLUGIN_VERSION::$(echo $PLUGIN_VERSION | grep -o '[0-9]*\.[0-9]*\.[0-9]*')

# Get revision
export PLUGIN_VERSION_REVISION=$(git rev-list --count HEAD)
echo ::set-env name=PLUGIN_VERSION_REVISION::$PLUGIN_VERSION_REVISION

# Set revision to superzombiefortress.sp
sed -i -e 's/#define PLUGIN_VERSION_REVISION.*".*"/#define PLUGIN_VERSION_REVISION "'$PLUGIN_VERSION_REVISION'"/g' superzombiefortress.sp
#!/bin/bash
set -xe

CURRENTVERS=$(awk -F\" '{ if ($1 == "var VERSION = ") print $2 }' $TYK_GW_PATH/data/version.go)
plugin_name=$1
plugin_id=$2
# GOOS and GOARCH can be send to override the name of the plugin
GOOS=$3
GOARCH=$4
CGOENABLED=0

PLUGIN_BUILD_PATH="/go/src/plugin_${plugin_name%.*}$plugin_id"

function usage() {
    cat <<EOF
To build a plugin:
      $0 <plugin_name> <plugin_id>

<plugin_id> is optional
EOF
}

# if params were not send, then attempt to get them from env vars
if [[ $GOOS == "" ]] && [[ $GOARCH == "" ]]; then
  GOOS=$(go env GOOS)
  GOARCH=$(go env GOARCH)
fi

if [ -z "$plugin_name" ]; then
    usage
    exit 1
fi

# if arch and os present then update the name of file with those params
if [[ $GOOS != "" ]] && [[ $GOARCH != "" ]]; then
  plugin_name="${plugin_name%.*}_${CURRENTVERS}_${GOOS}_${GOARCH}.so"
fi

if [[ $GOOS != "linux" ]];then
    CGO_ENABLED=1
fi


# for any dependency also present in Tyk, change the module version to Tyk's version
go list -m -f '{{ if not .Main }}{{ .Path }} {{ .Version }}{{ end }}' all > /tmp/plugin-deps.txt
(cd $TYK_GW_PATH && go list -m -mod=mod -f '{{ if not .Main }}{{ .Path }} {{ .Version }}{{ end }}' all > /tmp/gw-deps.txt)
awk 'NR==FNR{seen[$1]=$2; next} seen[$1] && seen[$1] != $2' /tmp/plugin-deps.txt /tmp/gw-deps.txt | while read PKG VER; do
  go mod edit -replace=$PKG=$PKG@$VER
done

cd $PLUGIN_SOURCE_PATH
CGO_ENABLED=$CGO_ENABLED GOOS=$GOOS GOARCH=$GOARCH go build -buildmode=plugin -o $plugin_name

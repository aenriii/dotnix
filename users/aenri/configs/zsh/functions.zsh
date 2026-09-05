function backup () {
  now=$(date +%s)
  cp -r $1 $1-$now
}

function $ () {
  "$@"
}

function cdtmp () {
  pushd $(mktemp -d)
}
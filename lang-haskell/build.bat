pushd build
@stack build --copy-bins
popd
@__shake-build\build-flare-timing %*

# Tested RPM repository

Successful component release jobs contribute their tested RPMs here through a
separate pull request. Each component version has its own local DNF repository
under `openeuler-22.03-lts-sp4/bigtop-3.6/<component>/<version>/`, including
`repodata/`, checksums, and a manifest recording the source CI run.

RPMs use Git LFS. Clone with Git LFS enabled to obtain the packages rather than
their pointer files. This directory is a versioned repository artifact; it is
not hosted as a public DNF endpoint by GitHub Pages.

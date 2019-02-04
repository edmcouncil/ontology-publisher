#!/usr/bin/env bash
#
# Install biber separately because TexLive doesn't have the right version
#

biber_tar_gz="biblatex-biber.tar.gz"
biber_version_dir="development"
biber_version_dir="current"
biber_tar_gz_url="https://sourceforge.net/projects/biblatex-biber/files/biblatex-biber/${biber_version_dir}/${biber_tar_gz}/download"

rm -f "/var/tmp/${biber_tar_gz}" >/dev/null 2>&1

curl --location --silent --show-error --output /var/tmp/${biber_tar_gz} --url "${biber_tar_gz_url}"

if [[ ! -f "/var/tmp/${biber_tar_gz}" ]] ; then
  echo "ERROR: Could not download ${biber_tar_gz_url}"
  exit 1
fi

rm -rf "/var/tmp/install-biber" >/dev/null 2>&1

mkdir -p "/var/tmp/install-biber" || exit 1
cd "/var/tmp/install-biber" || exit 1
tar xzf "/var/tmp/${biber_tar_gz}" --strip-components 1 -C . || exit 1
rm "/var/tmp/${biber_tar_gz}"

export PERL_MM_USE_DEFAULT=1

perl ./Build.PL
./Build
./Build installdeps
./Build install

cd /
rm -rf "/var/tmp/install-biber" >/dev/null 2>&1




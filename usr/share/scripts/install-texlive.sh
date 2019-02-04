#!/usr/bin/env bash

texlive_tar_gz="install-tl-unx.tar.gz"
texlive_tar_gz_url="http://mirror.ctan.org/systems/texlive/tlnet/${texlive_tar_gz}"

rm -rf "/usr/local/texlive" >/dev/null 2>&1
rm -rf "~/.texlive*" >/dev/null 2>&1
rm -f "/var/tmp/${texlive_tar_gz}" >/dev/null 2>&1

curl --location --silent --show-error --output /var/tmp/${texlive_tar_gz} --url "${texlive_tar_gz_url}"

if [[ ! -f "/var/tmp/${texlive_tar_gz}" ]] ; then
  echo "ERROR: Could not download ${texlive_tar_gz_url}"
  exit 1
fi

rm -rf "/var/tmp/install-texlive" >/dev/null 2>&1
mkdir -p /var/tmp/install-texlive || exit 1
cd /var/tmp/install-texlive || exit 1
tar xzf "/var/tmp/${texlive_tar_gz}" --strip-components 1 -C .
rm "/var/tmp/${texlive_tar_gz}"
ls -alG

cat > texlive.profile << __HERE__
# texlive.profile written on Sun Jul 23 14:41:25 2018 UTC
# It will NOT be updated and reflects only the
# installation profile at installation time.
selected_scheme scheme-custom
TEXDIR /usr/local/texlive/2018
TEXMFCONFIG ~/.texlive2018/texmf-config
TEXMFHOME ~/texmf
TEXMFLOCAL /usr/local/texlive/texmf-local
TEXMFSYSCONFIG /usr/local/texlive/2018/texmf-config
TEXMFSYSVAR /usr/local/texlive/2018/texmf-var
TEXMFVAR ~/.texlive2018/texmf-var
binary_x86_64-linux 1
binary_x86_64-linuxmusl 1
collection-basic 1
collection-bibtexextra 1
collection-binextra 1
collection-fontsrecommended 1
collection-fontutils 1
collection-langenglish 1
collection-langjapanese 0
collection-latex 1
collection-latexrecommended 1
collection-luatex 0
collection-mathscience 0
collection-metapost 1
collection-plaingeneric 1
collection-xetex 1
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 0
instopt_portable 0
instopt_write18_restricted 1
tlpdbopt_autobackup 1
tlpdbopt_backupdir tlpkg/backups
tlpdbopt_create_formats 1
tlpdbopt_desktop_integration 0
tlpdbopt_file_assocs 1
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
tlpdbopt_post_code 1
tlpdbopt_sys_bin /usr/local/bin
tlpdbopt_sys_info /usr/local/share/info
tlpdbopt_sys_man /usr/local/share/man
tlpdbopt_w32_multi_user 1
__HERE__

cat texlive.profile

echo "Running installer"

./install-tl --profile=texlive.profile

ln -s /usr/local/texlive/2018/texmf-var/fonts/conf/texlive-fontconfig.conf /etc/fonts/conf.d/09-texlive-fonts.conf

fc-cache -fsv

/usr/local/texlive/2018/bin/x86_64-linuxmusl/tlmgr install \
  blindtext enumitem appendix imakeidx glossaries mfirstuc xfor datatool substr lastpage glossaries-english

cd /
rm -rf /var/tmp
mkdir /var/tmp





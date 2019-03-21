#!/bin/bash
#
# Use this script if you're developing widoco in a repo next to this one.
# Copy the generated jar file (generate with "mvn package") to /usr/share/java/widoco
#
mkdir -p ./usr/share/java/widoco/
#
# TODO: Replace this path with yours
#
cp -v ${HOME}/Work/Widoco/jar/widoco-*-jar-with-dependencies.jar ./usr/share/java/widoco/widoco-launcher.jar

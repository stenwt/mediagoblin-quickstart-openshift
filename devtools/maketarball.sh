#!/bin/bash

# GNU MediaGoblin -- federated, autonomous media hosting
# Copyright (C) 2011, 2012 GNU MediaGoblin Contributors.  See AUTHORS.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# usage: maketarball [-drh] REVISH
#
# Creates a tarball of the repository at rev REVISH.

# If -d is passed in, then it adds the date to the directory name.
# 
# If -r is passed in, then it does some additional things required
# for a release-ready tarball.
#
# If -h is passed in, shows help and exits.
#
# Examples:
#
#    ./maketarball v0.0.2
#    ./maketarball -d master
#    ./maketarball -r v0.0.2


USAGE="Usage: $0 -h | [-dr] REVISH"

REVISH="none"
PREFIX="none"
NOWDATE=""
RELEASE="no"

while getopts ":dhr" opt;
do
    case "$opt" in
        h)
            echo "$USAGE"
            echo ""
            echo "Creates a tarball of the repository at rev REVISH."
            echo ""
            echo "   -h   Shows this help message"
            echo "   -d   Includes date in tar file name and directory"
            echo "   -r   Performs other release-related actions"
            exit 0
            ;;
        d)
            NOWDATE=`date "+%Y-%m-%d-"`
            shift $((OPTIND-1))
            ;;
        r)
            RELEASE="yes"
            shift $((OPTIND-1))
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "$USAGE" >&2
            ;;
    esac 
done

if [[ -z "$1" ]]; then
    echo "$USAGE";
    exit 1;
fi

REVISH=$1
PREFIX="$NOWDATE$REVISH"

# convert PREFIX to all lowercase and nix the v from tag names.
PREFIX=`echo "$PREFIX" | tr '[A-Z]' '[a-z]' | sed s/v//`

# build the filename base minus the .tar.gz stuff--this is also
# the directory in the tarball.
FNBASE="mediagoblin-$PREFIX"

STARTDIR=`pwd`

function cleanup {
    pushd $STARTDIR

    if [[ -e tmp ]]
    then
        echo "+ cleaning up tmp/"
        rm -rf tmp
    fi
    popd
}

echo "+ Building tarball from: $REVISH"
echo "+ Using prefix:          $PREFIX"
echo "+ Release?:              $RELEASE"

echo ""

if [[ -e tmp ]]
then
    echo "+ there's an existing tmp/.  please remove it."
    exit 1
fi

mkdir $STARTDIR/tmp
echo "+ generating archive...."
git archive \
    --format=tar \
    --prefix=$FNBASE/ \
    $REVISH > tmp/$FNBASE.tar

if [[ $? -ne 0 ]]
then
    echo "+ git archive command failed.  See above text for reason."
    cleanup
    exit 1
fi


if [[ $RELEASE = "yes" ]]
then
    pushd tmp/
    tar -xvf $FNBASE.tar

    pushd $FNBASE
    pushd docs

    echo "+ generating html docs"
    make html
    if [[ $? -ne 0 ]]
    then
        echo "+ sphinx docs generation failed.  See above text for reason."
        cleanup
        exit 1
    fi

    # NOTE: this doesn't work for gmg prior to v0.0.4.
    echo "+ generating texinfo docs (doesn't work prior to v0.0.4)"
    make info
    popd

    echo "+ moving docs to the right place"
    if [[ -e docs/build/html/ ]]
    then
        mv docs/build/html/ docs/html/
        mv docs/build/texinfo/ docs/texinfo/

        rm -rf docs/build/
    else
        # this is the old directory structure pre-0.0.4
        mv docs/_build/html/ docs/html/

        rm -rf docs/_build/
    fi

    popd

    tar -cvf $FNBASE.tar $FNBASE
    popd
fi


echo "+ compressing...."
gzip tmp/$FNBASE.tar

echo "+ archive at tmp/$FNBASE.tar.gz"

echo "+ done."
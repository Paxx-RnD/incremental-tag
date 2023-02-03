#!/bin/sh
set -eu

# Set up .netrc file with GitHub credentials
git_setup ( ) {
    git config --global user.email "actions@github.com"
    git config --global user.name "Incremental tag GitHub Action"
}

echo "###################"
echo "Tagging Parameters"
echo "###################"
echo "flag_branch: ${INPUT_FLAG_BRANCH}"
echo "message: ${INPUT_MESSAGE}"
echo "prev_tag: ${INPUT_PREV_TAG}"
echo "update_odoo_module_version: ${INPUT_UPDATE_ODOO_MODULE_VERSION}"
echo "GITHUB_ACTOR: ${GITHUB_ACTOR}"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN}"
echo "HOME: ${HOME}"
echo "###################"
echo ""
echo "Start process..."

echo "1) Setting up git machine..."
git_setup

echo "2) Updating repository tags..."
git fetch origin --tags --quiet

last_tag=""
if [ "${INPUT_FLAG_BRANCH}" = true ];then
    last_tag=$(git describe --tags $(git rev-list --tags) --always | grep v | sort -V -r | head -n 1)
    echo "Last tag: ${last_tag}";
else
    last_tag=`git describe --tags $(git rev-list --tags --max-count=1)`
    echo "Last tag: ${last_tag}";
fi


if [ -z "${last_tag}" ];then
    if [ "${INPUT_FLAG_BRANCH}" != false ];then
        last_tag="${INPUT_PREV_TAG}0.1.0";
    else
        last_tag="${INPUT_PREV_TAG}0.1.0";
    fi
    echo "Default Last tag: ${last_tag}";
fi

patch_number=$(echo "$last_tag" | awk -F. '{print $3}')
new_patch_number=$((patch_number + 1))
next_tag="$(echo "$last_tag" | awk -F. '{print $1"."$2"."}')$new_patch_number"
echo "3) Next tag: ${next_tag}";


if [ "${INPUT_UPDATE_ODOO_MODULE_VERSION}" = true ];then
    echo "4) Upload tag for Odoo module...";
    git checkout --quiet "${GITHUB_SHA}";

    for file in '__openerp__.py' '__manifest__.py';do
        if [ ! -f "${file}" ];then
            continue
        fi

        echo "Updating file version ${file}..."
        new_version=`echo ${next_tag}|sed "s,^v\(.*\),\1,g"`

        sed -i "s,\(\s*.version.*:\).*,\1 \"${new_version}\"\,,g" ${file}
        git add ${file}
    done

    git commit --allow-empty -m "${INPUT_MESSAGE}"
    tag_commit=`git rev-parse --verify HEAD`
    echo "5) Forcing tag update..."
    git tag ${next_tag}
    echo "6) Forcing tag push..."
    git push --tags
else
    echo "4) Forcing tag update..."
    git tag -a ${next_tag} -m "${INPUT_MESSAGE}" "${GITHUB_SHA}" -f
    echo "5) Forcing tag push..."
    git push --tags -f
fi

echo "::set-output name=tag::${next_tag}"

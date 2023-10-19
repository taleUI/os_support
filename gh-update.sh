#!/bin/bash

releasepath=$(cat /etc/gh-update-branch)
endpoint=https://github.com/taleUI/releases_${releasepath}

get_img_details(){
    stdout=$(jq 'sort_by(.created_at) | reverse')
    stdout=$(echo "${stdout}" | jq 'del(.[] | select(.assets[].state != "uploaded"))')
    download_img_url=$(echo "${stdout}" | jq -r '[ .[] | select(.prerelease==false) ] | first | .assets[] | select(.browser_download_url | test("img")) | .browser_download_url' | head -n1)
    download_sha256_url=$(echo "${stdout}" | jq -r '[ .[] | select(.prerelease==false) ] | first | .assets[] | select(.browser_download_url | test("img")) | .browser_download_url' | tail -n1)
    os_tag_name=$(echo "${stdout}" | jq -er '[ .[] | select(.prerelease==false) ] | first | .tag_name')
    if [[ "${os_tag_name}" == "$(cat /etc/os-release | grep VARIANT_ID | cut -d '=' f 2)" ]]; then
        UPDATE_AVAILABLE=False
        REPORTMSG="System up to date."
    else
        echo -e "OS_TAG_NAME=$os_tag_name\nDL_IMG=$download_img_url\nDL_SHA=$download_sha256_url" > /tmp/gh-update-temparg
        UPDATE_AVAILABLE=True
        REPORTMSG=$(echo -e "Update available. OS Update: ${os_tag_name}")
    fi
}

updatecheck(){
    CURL_ARGS="--http1.1 -L -s \"${endpoint}\""
    if [[ "${releasepath}" =~ "int" ]]; then
        if [[ -f "/etc/gh-update-token" ]]; then
            CURL_ARGS="---http1.1 -L -H \"Authorization: Bearer $(cat /etc/gh-update-token)\" -s \"${endpoint}\""
        else
            echo -e "You are on an internal build without an authorization to\nthe update endpoint.\nPlease pipe your valid Github token to /etc/gh-update-token via echo."
            exit 0
        fi
    fi
    curl $CURL_ARGS | get_img_details
    if [[ "${UPDATE_AVAILABLE}" == "True" ]]; then
        echo "${REPORTMSG}"
        exit 1
    else
        echo "${REPORTMSG}"
        exit 7
    fi
}

if [ -n "$1" ]; then
    case "$1" in
    "check")
	    updatecheck
        ;;
    "download-update")
        dlupd
        ;;
    "apply-now")
        if [[ -f "/tmp/gh-update-temparg" ]]; then
            gh-update-os --apply /tmp/gh-update-temparg
        else
            echo -e "No update arguments set. Checking for updates...\n"
            updatecheck
        fi
        ;;
    "-d")
        echo "No debug support check"
        updatecheck
        ;;
    esac
    shift
else
    echo "No option passed."
    exit 255
fi
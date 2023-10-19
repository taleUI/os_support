#!/bin/bash

argdata=/tmp/gh-update-temparg
ready_watcher=/tmp/gh-update-ready-to-deploy

releasepath=$(cat /etc/gh-update-branch)
endpoint=https://api.github.com/repos/taleUI/releases_${releasepath}/releases
downloadpath=/home/.gh_offload/updatecontainer

get_img_details(){
    stdout=$(jq 'sort_by(.created_at) | reverse')
    stdout=$(echo "${stdout}" | jq 'del(.[] | select(.assets[].state != "uploaded"))')
    download_img_url=$(echo "${stdout}" | jq -r '[ .[] | select(.prerelease==false) ] | first | .assets[] | select(.browser_download_url | test("img")) | .browser_download_url' | head -n1)
    download_sha256_url=$(echo "${stdout}" | jq -r '[ .[] | select(.prerelease==false) ] | first | .assets[] | select(.browser_download_url | test("img")) | .browser_download_url' | tail -n1)
    os_tag_name=$(echo "${stdout}" | jq -er '[ .[] | select(.prerelease==false) ] | first | .tag_name')
    if [[ "${os_tag_name}" == "$(cat /etc/os-release | grep VARIANT_ID | cut -d '=' -f 2)" ]]; then
        echo "System up to date."
    else
        echo -e "OS_TAG_NAME=$os_tag_name\nDL_IMG=$download_img_url\nDL_SHA=$download_sha256_url" > ${argdata}
        echo "Update available. OS Update: ${os_tag_name}"
    fi
}

updatecheck(){
    if [[ "${releasepath}" =~ "int" ]]; then
        if [[ -f "/etc/gh-update-token" ]]; then
            curl --http1.1 -L -H "Authorization: Bearer $(cat /etc/gh-update-token)" -s "${endpoint}" | get_img_details
        else
            echo -e "You are on an internal build without an authorization to\nthe update endpoint.\nPlease pipe your valid Github token to /etc/gh-update-token via echo."
            exit 0
        fi
    else
        curl --http1.1 -L -s "${endpoint}" | get_img_details
    if [[ -f "${argdata}" ]]; then
        exit 7
    else
        exit 1
    fi
    fi
}

if [ -n "$1" ]; then
    case "$1" in
    "check")
	    updatecheck
        ;;
    "download-update")
        if [[ -f "${argdata}" ]]; then
            dlupd
        else
            updatecheck
            if [[ -f "${argdata}" ]]; then
                dlupd
            fi
        fi
        ;;
    "apply-now")
        if [[ -f "${argdata}" ]]; then
            dlupd
            if [[ -f "${ready_watcher}" ]]; then
                gh-update-os --apply ${argdata}
            fi
        else
            echo -e "No update arguments set. Checking for updates...\n"
            updatecheck
        fi
        ;;
    "-d")
        echo "No debug support check"
        updatecheck
        ;;
    "*")
        echo "Invalid option $1"
        exit 1
        ;;
    esac
    shift
else
    echo "No option passed."
    exit 255
fi
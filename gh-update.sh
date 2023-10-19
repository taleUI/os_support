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
        UPDATE_AVAILABLE=True
        REPORTMSG=$(echo -e "Update available. OS Update: ${os_tag_name}")
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
            echo "No update arguments set. Checking for updates..."
            updatecheck
        fi
        ;;
    "-d")
        echo "No debug support check"
        updatecheck
        ;;
    '*')
	    echo "Option not passed"
        ;;
    esac
    shift
fi
fi
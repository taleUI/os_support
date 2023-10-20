#!/bin/bash

argdata=/tmp/gh-update-temparg
ready_watcher=/tmp/gh-update-ready-to-deploy

releasepath=$(cat /etc/gh-update-branch)
endpoint=https://api.github.com/repos/taleUI/releases_${releasepath}/releases
downloadpath=/home/.gh_offload/updatecontainer

get_img_details(){
    stdout=$(jq 'sort_by(.created_at) | reverse')
    stdout=$(echo "${stdout}" | jq 'del(.[] | select(.assets[].state != "uploaded"))')
    os_tag_name=$(echo "${stdout}" | jq -er '[ .[] | select(.prerelease==false) ] | first | .tag_name')
    download_img_id=$(echo "${stdout}" | jq -er '[ .[] | select(.prerelease==false) ] | first | .assets[] | .url' | head -n1)
    download_sha_id=$(echo "${stdout}" | jq -er '[ .[] | select(.prerelease==false) ] | first | .assets[] | .url' | tail -n1)
    if [[ "${os_tag_name}" == "$(cat /etc/os-release | grep VARIANT_ID | cut -d '=' -f 2)" ]]; then
        echo "System up to date."
    else
        echo -e "OS_TAG_NAME=$os_tag_name\nDL_IMG=$download_img_url\nDL_SHA=$download_sha256_url\nGH_IMG_DL=$download_img_id\nGH_SHA_DL=$download_sha_id" > ${argdata}
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

verintg(){
    echo "Verifying update file integrity..."
    CURR_SHA=$(echo $(sha256sum ${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst) | awk '{print $1}')
    if [[ "${CURR_SHA}" == "$(cat ${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst.sha256)" ]]; then
        touch ${ready_watcher}
        echo "Update file download complete. The system is ready to update."
    else
        rm -rf ${downloadpath}/${OS_TAG_NAME}
        echo "Verification failed. Download contents erased."
        exit 1
    fi
}

dlupd(){
    source ${argdata}
    if [[ -f "${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst" ]] && [[ -f "${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst.sha256" ]]; then
        verintg
    else
        mkdir -p ${downloadpath}/${OS_TAG_NAME}
        echo "Downloading update files..."
        if [[ "${releasepath}" =~ "int" ]]; then
            if [[ -f "/etc/gh-update-token" ]]; then
                curl --http1.1 -L -H "Accept: application/octet-stream" -H "Authorization: Bearer $(cat /etc/gh-update-token)" -o ${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst "${GH_IMG_DL}"
                curl --http1.1 -L -H "Accept: application/octet-stream" -H "Authorization: Bearer $(cat /etc/gh-update-token)" -o ${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst.sha256 "${GH_SHA_DL}"
            else
                echo -e "You are on an internal build without an authorization to\nthe update endpoint.\nPlease pipe your valid Github token to /etc/gh-update-token via echo."
                exit 0
            fi
        else
            curl --http1.1 -L -H "Accept: application/octet-stream" -o ${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst "${GH_IMG_DL}"
            curl --http1.1 -L -H "Accept: application/octet-stream" -o ${downloadpath}/${OS_TAG_NAME}/${OS_TAG_NAME}.img.zst.sha256 "${GH_SHA_DL}"
        fi
        verintg
    fi
}

if [ -n "$1" ]; then
    case "$1" in
    "check")
        rm -f ${argdata} ${ready_watcher}
	    updatecheck
        ;;
    "download-update")
        if [[ -f "${argdata}" ]]; then
            dlupd
        else
            echo "Update arguments are not yet available. Please try checking for updates first."
            exit 1
        fi
        ;;
    "apply-now")
        if [[ -f "${ready_watcher}" ]]; then
            gh-update-os --apply ${argdata}
            exit 7
        fi
        if [[ -f "${argdata}" ]]; then
            dlupd
            if [[ -f "${ready_watcher}" ]]; then
                gh-update-os --apply ${argdata}
                exit 7
            fi
        else
            echo -e "No update arguments set. Checking for updates...\n"
            updatecheck
            dlupd
            if [[ -f "${ready_watcher}" ]]; then
                gh-update-os --apply ${argdata}
                exit 7
            fi
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
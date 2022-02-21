# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Check any previous images"

SHA=$(sha256sum ${BASE_IMAGE})
echo "SHA: ${SHA}"

if [[ "${HAS_CUSTOM_BASE}" == true ]]; then    

echo "Downloading custom build base image"
bash ../../scripts/gdrive.sh ${BASE_IMAGE_URL}
rm uc* SKIP
if [ -z "$(ls -A .)" ]; then
   echo "Google-Drive error, downloading from slower mirror instead"
   wget -q --show-progress --progress=bar:force:noscroll $BASE_IMAGE_Mirror/$BASE_IMAGE 
fi
SHA=$(sha256sum ${BASE_IMAGE})
echo "SHA: ${SHA}"
fi



if [[ "${SHA}" != "${BASE_IMAGE_SHA256}  ${BASE_IMAGE}" ]]; then    
    rm *.zip
    rm *.img    
    rm *.xz
    rm *.7z
	
    		log "Download base Image"
    		wget -q --show-progress --progress=bar:force:noscroll $BASE_IMAGE_URL/$BASE_IMAGE 
	fi





log "Unarchive base image"

if [[ ${BASE_IMAGE: -4} == ".zip" ]]; then
    unzip ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -7} == ".img.xz" ]; then
    xz -k -d ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -4} == ".bz2" ]; then
    bunzip2 -k -d ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -3} == ".gz" ]; then
    gunzip -k ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -3} == ".7z" ]; then
    7z e ${BASE_IMAGE}

fi

mv *.[iI][mM][gG] IMAGE.img

# return
popd



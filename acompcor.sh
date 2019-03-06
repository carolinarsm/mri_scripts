# This function runs aCompCor similarly to what described in Behzadi et al 2007
# (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2214855/). The output file
# contains the aCompCor regressors (first 5 eigenvariates after a SVD). The script
# requires FSL to run. The first argument is an aparc+aseg image
# generated by Freesurfer. The second argument is an fMRI 4D dataset. The two images have to be in the same space (but can be at different resolutions).


aparcaseg=$1
func=$2
DIR=$(dirname "${1}")

cd $DIR
mkdir temp

# Extracting the CSF regions from the FS segmentation
fslmaths "${aparcaseg}" -thr 4 -uthr 5 -bin temp/Lven_mask.nii.gz
fslmaths "${aparcaseg}" -thr 43 -uthr 44 -bin temp/Rven_mask.nii.gz
fslmaths "${aparcaseg}" -thr 14 -uthr 15 -bin temp/45ven_mask.nii.gz
fslmaths "${aparcaseg}" -thr 24 -uthr 24 -bin temp/csf_mask.nii.gz

# Merging the regions
fslmaths 'temp/Lven_mask.nii.gz' -add 'temp/Rven_mask.nii.gz' -add 'temp/45ven_mask.nii.gz' -add 'temp/csf_mask.nii.gz' 'temp/csfmerge_mask.nii.gz'

# Eroding the CSF mask
fslmaths 'temp/csfmerge_mask.nii.gz' -kernel boxv 3x3x3 -ero 'temp/csfmerge_mask_ero.nii.gz'

# Extracting the WM regions from the FS segmentation
fslmaths "${aparcaseg}" -thr 2 -uthr 2 -bin 'temp/wmL_mask.nii.gz'
fslmaths "${aparcaseg}" -thr 41 -uthr 41 -bin 'temp/wmR_mask.nii.gz'

# Merging the regions
fslmaths 'temp/wmL_mask.nii.gz' -add 'temp/wmR_mask.nii.gz' 'temp/wmmerge_mask.nii.gz'

# Eroding the WM mask (in this case I selected a stronger erosion)
fslmaths 'temp/wmmerge_mask.nii.gz' -kernel boxv 5x5x5 -ero 'temp/wmmerge_mask_ero.nii.gz'

# Merging the CSF and WM masks
fslmaths 'temp/csfmerge_mask_ero.nii.gz' -add 'temp/wmmerge_mask_ero.nii.gz' 'noise_mask.nii.gz'

# Taking one volume of the fMRI as reference for FLIRT
fslroi "${func}" 'temp/onevol.nii.gz' 0 1

# Coregistering segmentation to fMRI
flirt -in "${aparcaseg}" -ref 'temp/onevol.nii.gz' -interp nearestneighbour -omat 'temp/matrix'

# Applying transformation to mask
flirt -in 'noise_mask.nii.gz' -out 'noise_mask_fMRIspace.nii.gz' -ref 'temp/onevol.nii.gz' -interp nearestneighbour -init 'temp/matrix' -applyxfm

# Cleaning up
rm -r temp/

# aCompCor step: SVD of the timeseries and saving 5 eigenvariates
fslmeants -i ${func} -m 'noise_mask_fMRIspace.nii.gz' -o "${func}_acompcor_svd.txt" --eig --order=5

#!/usr/bin/env bash
DEFAULT_MEDIA_PATH=${JELLYFIN_LIVESTREAM_DEFAULT_MEDIA_PATH:-}
TRANSCODE_DIR=${JELLYFIN_LIVESTREAM_TRANSCODE_DIR:-/config/transcodes}

path=$1

function cleanup() {
    echo "Cleaning up transcode files..."
    rm "$TRANSCODE_DIR"/"$filename"*
    echo "Done. Exiting..."
    exit
}

# Remove trailing / if it exists
if [[ "$DEFAULT_MEDIA_PATH" == */ ]]
then
    DEFAULT_MEDIA_PATH=${DEFAULT_MEDIA_PATH::-1}
fi

# Remove trailing / if it exists
if [[ "$TRANSCODE_DIR" == */ ]]
then
    TRANSCODE_DIR=${TRANSCODE_DIR::-1}
fi

# Check if path given is absolute.
if [[ "$path" != /* ]]
then
    if [ -z "${DEFAULT_MEDIA_PATH}" ]
    then
        echo "ERROR: A relative path was given but not default path has been set. Please provide an absolute path or set a default path."
        exit 1
    else
        absolute_path="$DEFAULT_MEDIA_PATH/$path"
    fi
else
    absolute_path=$path
fi

# get filename without file extention from path
filename=$(basename "$absolute_path" .mkv)

trap cleanup SIGINT

/usr/lib/jellyfin-ffmpeg/ffmpeg -re -analyzeduration 200M -fflags +genpts -f matroska,webm -i file:"$absolute_path" \
-map_metadata -1 -map_chapters -1 -threads 0 -map 0:0 -map 0:1 -map -0:s -codec:v:0 copy -bsf:v h264_mp4toannexb -start_at_zero \
-codec:a:0 copy -copyts -avoid_negative_ts disabled -max_muxing_queue_size 2048 \
-f hls -max_delay 5000000 -hls_time 6 -hls_segment_type mpegts -start_number 0 \
-hls_segment_filename "$TRANSCODE_DIR/$filename%d.ts" -hls_playlist_type vod \
-hls_list_size 0 -y "$TRANSCODE_DIR/$filename.m3u8"

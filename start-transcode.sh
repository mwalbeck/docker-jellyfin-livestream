#!/usr/bin/env bash
DEFAULT_PATH=${JELLYFIN_LIVESTREAM_DEFAULT_PATH:-}

path=$1

if [[ "$path" != /* ]]
then
    if [ -z "${DEFAULT_PATH}" ]
    then
        echo "ERROR: A relative path was given but not default path has been set. Please provide an absolute path or set a default path."
        exit 1
    else
        absolute_path="$DEFAULT_PATH/$path"
    fi
else
    absolute_path=$path
fi

# get filename without file extention from path
filename=$(basename "$absolute_path" .mkv)

/usr/lib/jellyfin-ffmpeg/ffmpeg -re -fflags +genpts -f matroska,webm -i file:"$absolute_path" \
-map_metadata -1 -map_chapters -1 -threads 0 -map 0:0 -map 0:1 -map -0:s -codec:v:0 copy -start_at_zero \
-vsync -1 -codec:a:0 copy -strict -2 -copyts -avoid_negative_ts disabled -max_muxing_queue_size 2048 \
-f hls -max_delay 5000000 -hls_time 6 -hls_segment_type mpegts -start_number 0 \
-hls_segment_filename "/config/transcodes/$filename%d.ts" -hls_playlist_type vod \
-hls_list_size 0 -y "/config/transcodes/$filename.m3u8"

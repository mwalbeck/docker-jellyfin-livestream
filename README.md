# docker-jellyfin-livestream

[![Build Status](https://build.walbeck.it/api/badges/mwalbeck/docker-jellyfin-livestream/status.svg)](https://build.walbeck.it/mwalbeck/docker-jellyfin-livestream)
![Docker Pulls](https://img.shields.io/docker/pulls/mwalbeck/jellyfin-livestream)

Docker image for custom version of [Jellyfin](https://github.com/jellyfin/jellyfin/) available at [Docker Hub](https://hub.docker.com/r/mwalbeck/jellyfin-livestream).

For questions head and source code over to the git repo [here](https://git.walbeck.it/mwalbeck/docker-jellyfin-livestream) or on [GitHub](https://github.com/mwalbeck/docker-jellyfin-livestream).

Please note, this container should only be used for watching livestreams via SyncPlay and is not ideal for normal usage.

## Setup

### Container

The container is intended to be a drop-in replacement for the official one, with one required and one optional config option. If you're unsure how to get started with the official docker container you can have a look at the instruction from the Jellyfin wiki [here](https://jellyfin.org/docs/general/administration/installing.html#docker).

The two options are configured through environment variables and are `JELLYFIN_LIVESTREAM_TRANSCODE_DIR` and `JELLYFIN_LIVESTREAM_DEFAULT_MEDIA_PATH`.

`JELLYFIN_LIVESTREAM_TRANSCODE_DIR` has to be set to the transcode directory used by Jellyfin, or it won't work properly. By default, it is set to `/config/transcodes`.

`JELLYFIN_LIVESTREAM_DEFAULT_MEDIA_PATH` is a quality of life option allowing you to set the path to the media library that will contain the livestreams. This allows you to run the helper script with just the name of the file instead of the absolute path. Remember it should be the path to the library inside the container.

When you have the container up and running and a livestream download going you can start the transcode using the below command:

```
docker exec -it CONTAINER_NAME start-transcode livestream.mkv
```

If you didn't specify a default media path, use the absolute path to livestream.mkv inside the container instead. To stop the transcode you can just do a Ctrl+C, that will stop the FFmpeg process and clean up the transcode cache.

### A livestream and a long MKV file.

To get a livestream you want to watch with some friends, I would recommend [Streamlink](https://github.com/streamlink/streamlink). It's a great program and very easy to use. Now most if not all livestreams you download will be stored in a .mp4 container where we want an MKV container. To get that you have two options.

First options is to either pipe the stream directly to FFmpeg and have FFmpeg remux the stream into a mkv container with an arbitrarily long length. In this example I use 6 hours.
```
streamlink -O "LIVESTREAM_LINK" best | ffmpeg -i pipe: -codec copy -t 06:00:00 livestream.mkv
```

Or you can save the .mp4 and then have FFmpeg read from that file in real-time.
```
streamlink -o temp.mp4 "LIVESTREAM_LINK" best
```
And then
```
ffmpeg -re -i temp.mp4 -codec copy -t 06:00:00 livestream.mkv
```

The first option is nice because you don't have to store the video twice, but I have experienced issue with the audio being delay using that method. If you run into that as well try out the second method.

To manage it all I can definitely recommend having a look at tmux or screen to make everything easier.

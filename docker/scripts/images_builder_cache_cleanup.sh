#!/bin/bash

###################################################
# Author: Robson Martins
# GitHub: https://github.com/robsoncombr
###################################################

# Script to Clean Up Docker `<none>` Images and Prune Build Cache
#
# Description:
# This script is designed to help Docker users clean up untagged (`<none>`) images
# from their local Docker environment. Untagged images, also known as `<none>` images,
# are layers or images that no longer have a tag associated with them. These images
# often accumulate over time due to incomplete builds, re-tagging, or the creation of
# new image layers that leave the old ones behind. While these images might not be
# immediately visible, they can take up significant disk space.
#
# What are `<none>` Images?
# `<none>` images are Docker images that do not have a repository or tag associated
# with them. They typically result from:
# - Docker builds that generate intermediate layers.
# - Updates or re-tagging of images, where the old versions remain as `<none>`.
# - Incomplete or interrupted builds.
#
# Checking for `<none>` Images:
# You can manually check for the presence of `<none>` images using the following commands:
# - `docker image ls`: This command lists all images, and you can identify `<none>`
#   images by looking for entries where the "REPOSITORY" or "TAG" column shows `<none>`.
# - `docker system df`: This command provides a summary of Docker's disk usage, including
#   the total space used by images. It will help you see how much space is potentially
#   reclaimable by removing `<none>` images.
#
# How It Works:
# 1. The script first identifies all Docker images with `<none>` as their tag or repository.
# 2. If such images are found, it removes them one by one using the `docker rmi` command.
# 3. After removing the `<none>` images, the script then prunes the Docker build cache
#    using the `docker builder prune` and `docker buildx prune` commands, which
#    help to free up space by clearing out unused build data.
#
# Intended Audience:
# This script is intended for beginners and anyone in the Docker community looking
# for a simple way to manage their Docker environment and reclaim disk space.
# It is especially useful for those who frequently build Docker images and want to
# maintain a clean and efficient system.

# List all Docker images that have `<none>` as their tag or repository.
none_images=$(docker images | grep "<none>" | awk '{print $3}')

# Check if there are any `<none>` images.
if [ -z "$none_images" ]; then
    echo "No <none> images to remove."
else
    # Loop through each `<none>` image and remove it using `docker rmi`.
    for image_id in $none_images; do
        echo "Removing <none> image: $image_id"
        docker rmi "$image_id"
    done
    echo "All <none> images have been removed."
fi

# Prune the Docker build cache to free up disk space.
#docker builder prune -f
docker builder prune -f --filter "until=24h"

# Prune the Docker Buildx cache to free up additional disk space.
#docker buildx prune -f
docker buildx prune -f --filter "until=24h"

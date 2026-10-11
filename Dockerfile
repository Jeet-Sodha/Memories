# Builds the Memories Android APK (and runs flutter analyze) inside Docker.
# Image already contains Flutter + Android SDK + Java.
FROM ghcr.io/cirruslabs/flutter:stable

RUN apt-get update && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY tools /src/tools
COPY docker/build.sh /usr/local/bin/build-memories
RUN chmod +x /usr/local/bin/build-memories

# lib/ is mounted at runtime (see docker-compose.yml) so you can edit
# lib/config/supabase_config.dart without rebuilding the image.
ENTRYPOINT ["build-memories"]
CMD ["apk"]

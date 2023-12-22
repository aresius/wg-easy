# There's an issue with node:20-alpine.
# Docker deployment is canceled after 25< minutes.

FROM docker.io/library/node:18-alpine AS build_node_modules

# Hide fund and update-notifier message
RUN npm config set -g fund false &&\
    npm config set -g update-notifier false

# Copy Web UI
COPY src/ /app/
WORKDIR /app
RUN npm ci
# Copy build result to a new image.
# This saves a lot of disk space.
FROM docker.io/library/node:18-alpine

# Hide fund and update-notifier message
RUN npm config set -g fund false &&\
    npm config set -g update-notifier false

COPY --from=build_node_modules /app /app

# Move node_modules one directory up, so during development
# we don't have to mount it in a volume.
# This results in much faster reloading!
#
# Also, some node_modules might be native, and
# the architecture & OS of your development machine might differ
# than what runs inside of docker.
RUN mv /app/node_modules /node_modules

# Enable this to run `npm run serve`
RUN npm i -g nodemon

# Install Linux packages
RUN apk add -U --no-cache \
    dpkg \
    dumb-init \
    iptables \
    iptables-legacy \
    wireguard-tools

# Symlink iptables
RUN update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

# switch to nftables
RUN ln -sf xtables-nft-multi /sbin/iptables
RUN ln -sf xtables-nft-multi /sbin/iptables-save
RUN ln -sf xtables-nft-multi /sbin/iptables-restore

# Expose Ports
EXPOSE 51820/udp
EXPOSE 51821/tcp

# Set Environment
ENV DEBUG=Server,WireGuard

# Run Web UI
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]

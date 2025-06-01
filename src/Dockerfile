FROM node:22.16.0-alpine3.22

# Create app directory and set permissions
RUN mkdir -p /home/node/app && chown -R node:node /home/node/app

# Set working directory
WORKDIR /home/node/app

# Copy package files and install dependencies as node user
COPY --chown=node:node package*.json ./
USER node
RUN npm install

# Copy the rest of the application code as node user
COPY --chown=node:node . .

USER root
# Install security updates
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

USER node

# Start the app
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD test -f /home/node/app/src/app.js || exit 1
CMD ["node", "src/app.js"]
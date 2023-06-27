FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json .
RUN npm install
COPY . .
RUN npm run build
RUN npm prune --production
RUN ls -lisa build/client/_app

FROM node:20-alpine
WORKDIR /app
RUN cat /etc/passwd
COPY --from=builder /app/build build/
COPY --from=builder /app/node_modules node_modules/
COPY package.json .
VOLUME /app/build/client/images/
RUN chown node  -R .
EXPOSE 3000
ENV NODE_ENV=production
RUN chown node build/client/images
RUN ls -lisa build/client/_app
RUN ls -lisa /app
CMD [ "node", "build" ]

FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

# Expose port for SSE (if used) or stdio
EXPOSE 8889

CMD ["npm", "start"]

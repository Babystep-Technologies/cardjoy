# Use an official node runtime as a parent image
FROM node:latest

WORKDIR /app/admin

# add `/app/node_modules/.bin` to $PATH
# ENV PATH /app/web/node_modules/.bin:$PATH

# # Add rest of the client code
COPY . /app/admin

CMD ["node"]

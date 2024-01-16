FROM nginx

COPY ./dist /data/nginx/html

ENTRYPOINT ["nginx", "-g", "daemon off;"]

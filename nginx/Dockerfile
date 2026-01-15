# Dockerfile pour le Reverse Proxy Nginx
FROM nginx:1.27-alpine

# Copier la configuration Nginx
COPY nginx-simple.conf /etc/nginx/conf.d/default.conf

# Créer le répertoire pour la config de routing
RUN mkdir -p /etc/nginx/conf.d

# Copier la config de routing par défaut (blue)
COPY active_routing_blue.conf /etc/nginx/conf.d/active_routing.conf

# Exposer le port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/proxy-health || exit 1

CMD ["nginx", "-g", "daemon off;"]

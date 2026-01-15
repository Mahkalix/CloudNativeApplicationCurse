# Dockerfile pour le Reverse Proxy Nginx
FROM nginx:1.27-alpine

# Supprimer la config par défaut
RUN rm /etc/nginx/conf.d/default.conf

# Copier la configuration Nginx simple par défaut (sans GREEN)
COPY nginx-simple.conf /etc/nginx/conf.d/default.conf

# Exposer le port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/proxy-health || exit 1

CMD ["nginx", "-g", "daemon off;"]

# Dockerfile pour le Reverse Proxy Nginx
FROM nginx:1.27-alpine

# Supprimer la config par défaut
RUN rm /etc/nginx/conf.d/default.conf

# Copier les configurations blue/green complètes
COPY nginx-bluegreen-blue.conf /etc/nginx/conf.d/nginx-bluegreen-blue.conf
COPY nginx-bluegreen-green.conf /etc/nginx/conf.d/nginx-bluegreen-green.conf

# Utiliser la configuration BLUE par défaut
COPY nginx-bluegreen-blue.conf /etc/nginx/conf.d/default.conf

# Copier le fichier de couleur active
COPY active_color.txt /etc/nginx/active_color.txt

# Exposer le port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/proxy-health || exit 1

CMD ["nginx", "-g", "daemon off;"]

# Dockerfile pour le Reverse Proxy Nginx
FROM nginx:1.27-alpine

# Supprimer la config par défaut
RUN rm /etc/nginx/conf.d/default.conf

# Copier la configuration Nginx blue/green dynamique
COPY nginx-bluegreen.conf /etc/nginx/conf.d/default.conf

# Copier les fichiers de routing
COPY active_routing_blue.conf /etc/nginx/conf.d/active_routing_blue.conf
COPY active_routing_green.conf /etc/nginx/conf.d/active_routing_green.conf

# Copier le fichier de routing actif par défaut (BLUE)
COPY active_routing_blue.conf /etc/nginx/conf.d/active_routing.conf

# Copier le fichier de couleur active
COPY active_color.txt /etc/nginx/active_color.txt

# Exposer le port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/proxy-health || exit 1

CMD ["nginx", "-g", "daemon off;"]

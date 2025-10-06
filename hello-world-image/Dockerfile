FROM nginx:alpine

# Create a simple HTML page
RUN echo '<!DOCTYPE html>' > /usr/share/nginx/html/index.html && \
    echo '<html lang="en">' >> /usr/share/nginx/html/index.html && \
    echo '<head>' >> /usr/share/nginx/html/index.html && \
    echo '    <meta charset="UTF-8">' >> /usr/share/nginx/html/index.html && \
    echo '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' >> /usr/share/nginx/html/index.html && \
    echo '    <title>Hello World</title>' >> /usr/share/nginx/html/index.html && \
    echo '    <style>' >> /usr/share/nginx/html/index.html && \
    echo '        body {' >> /usr/share/nginx/html/index.html && \
    echo '            font-family: Arial, sans-serif;' >> /usr/share/nginx/html/index.html && \
    echo '            display: flex;' >> /usr/share/nginx/html/index.html && \
    echo '            justify-content: center;' >> /usr/share/nginx/html/index.html && \
    echo '            align-items: center;' >> /usr/share/nginx/html/index.html && \
    echo '            height: 100vh;' >> /usr/share/nginx/html/index.html && \
    echo '            margin: 0;' >> /usr/share/nginx/html/index.html && \
    echo '            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);' >> /usr/share/nginx/html/index.html && \
    echo '        }' >> /usr/share/nginx/html/index.html && \
    echo '        .container {' >> /usr/share/nginx/html/index.html && \
    echo '            text-align: center;' >> /usr/share/nginx/html/index.html && \
    echo '            background: white;' >> /usr/share/nginx/html/index.html && \
    echo '            padding: 3rem;' >> /usr/share/nginx/html/index.html && \
    echo '            border-radius: 10px;' >> /usr/share/nginx/html/index.html && \
    echo '            box-shadow: 0 10px 25px rgba(0,0,0,0.2);' >> /usr/share/nginx/html/index.html && \
    echo '        }' >> /usr/share/nginx/html/index.html && \
    echo '        h1 {' >> /usr/share/nginx/html/index.html && \
    echo '            color: #667eea;' >> /usr/share/nginx/html/index.html && \
    echo '            margin: 0 0 1rem 0;' >> /usr/share/nginx/html/index.html && \
    echo '        }' >> /usr/share/nginx/html/index.html && \
    echo '        p {' >> /usr/share/nginx/html/index.html && \
    echo '            color: #555;' >> /usr/share/nginx/html/index.html && \
    echo '            font-size: 1.2rem;' >> /usr/share/nginx/html/index.html && \
    echo '        }' >> /usr/share/nginx/html/index.html && \
    echo '        .badge {' >> /usr/share/nginx/html/index.html && \
    echo '            background: #764ba2;' >> /usr/share/nginx/html/index.html && \
    echo '            color: white;' >> /usr/share/nginx/html/index.html && \
    echo '            padding: 0.5rem 1rem;' >> /usr/share/nginx/html/index.html && \
    echo '            border-radius: 20px;' >> /usr/share/nginx/html/index.html && \
    echo '            display: inline-block;' >> /usr/share/nginx/html/index.html && \
    echo '            margin-top: 1rem;' >> /usr/share/nginx/html/index.html && \
    echo '        }' >> /usr/share/nginx/html/index.html && \
    echo '    </style>' >> /usr/share/nginx/html/index.html && \
    echo '</head>' >> /usr/share/nginx/html/index.html && \
    echo '<body>' >> /usr/share/nginx/html/index.html && \
    echo '    <div class="container">' >> /usr/share/nginx/html/index.html && \
    echo '        <h1>Hello World!</h1>' >> /usr/share/nginx/html/index.html && \
    echo '        <p>From My Local Image<br>from my Air Gapped Lab!</p>' >> /usr/share/nginx/html/index.html && \
    echo '        <div class="badge">🔒 Offline Registry</div>' >> /usr/share/nginx/html/index.html && \
    echo '    </div>' >> /usr/share/nginx/html/index.html && \
    echo '</body>' >> /usr/share/nginx/html/index.html && \
    echo '</html>' >> /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

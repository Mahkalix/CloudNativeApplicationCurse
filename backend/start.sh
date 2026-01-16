#!/bin/sh
set -e

echo "🚀 Starting backend application..."
echo "Environment: ${NODE_ENV:-production}"
echo "Instance ID: ${INSTANCE_ID:-unknown}"

# Run Prisma migrations
echo "📦 Running Prisma migrations..."
if npx prisma migrate deploy; then
  echo "✅ Prisma migrations completed successfully"
else
  echo "❌ Prisma migrations failed!"
  echo "DATABASE_URL: ${DATABASE_URL}"
  echo "Checking database connection..."
  npx prisma db execute --stdin <<EOF || echo "⚠️ Could not connect to database"
SELECT 1;
EOF
  exit 1
fi

# Start the application
echo "🎯 Starting Node.js application..."
exec node src/index.js

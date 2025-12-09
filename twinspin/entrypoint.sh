#!/bin/sh
set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "${DATABASE_HOST:-db}" -p "${DATABASE_PORT:-5432}" -U "${DATABASE_USER:-postgres}" -q; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is ready!"

# Run migrations
echo "Running database migrations..."
/app/bin/twinspin eval "Twinspin.Release.migrate"

# Create initial settings if needed
echo "Ensuring initial settings exist..."
/app/bin/twinspin eval "
case Twinspin.Repo.get(Twinspin.Settings.Settings, 1) do
  nil ->
    IO.puts(\"Creating initial settings...\")
    %Twinspin.Settings.Settings{id: 1, brand_name: \"TwinSpin\"}
    |> Twinspin.Repo.insert!()
    IO.puts(\"Initial settings created\")
  _ ->
    IO.puts(\"Settings already exist\")
end
"

echo "Starting TwinSpin..."
# Execute the CMD passed to the container
exec "$@"


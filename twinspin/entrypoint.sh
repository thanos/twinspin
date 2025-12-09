#!/bin/bash
set -e

echo "====================================="
echo "TwinSpin Docker Container Starting"
echo "====================================="

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
while ! pg_isready -h postgres -U postgres -q; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is ready!"

# Run database migrations
echo "Running database migrations..."
bin/twinspin eval "Twinspin.Release.migrate"

# Create initial settings if needed
echo "Creating initial settings..."
bin/twinspin eval "
  case Twinspin.Repo.get(Twinspin.Settings, 1) do
    nil ->
      %Twinspin.Settings{id: 1, brand_name: \"TwinSpin\"}
      |> Twinspin.Repo.insert!()
      IO.puts(\"Initial settings created\")
    _ ->
      IO.puts(\"Settings already exist\")
  end
"

echo "====================================="
echo "Starting TwinSpin Application"
echo "====================================="

# Execute the main command
exec "$@"


# FactorioHQ

FactorioHQ is a web application for managing Factorio game servers using Docker containers. It provides a user-friendly interface to create, configure, and manage multiple Factorio servers.

## Features

- Create and manage multiple Factorio servers
- Configure server settings (port, password, max players, etc.)
- Start, stop and update servers with a single click
- Upload and manage save files
- View server and game logs in real-time
- Manage server mods
- Uses the [factoriotools](https://hub.docker.com/r/factoriotools/factorio/) Docker image to run game servers

#### Manage Multiple Servers
![Manage Multiple Servers](screenshots/servers.png)

#### View Server Details
![View Server Details](screenshots/server-details.png)

#### Configure Server Settings
![Configure Server Settings](screenshots/settings.png)

#### Manage Mods
![Manage Mods](screenshots/mods.png)

## Requirements

- Ruby 3.2.4
- Rails 8.0.2
- Docker

## Installation

⚠️ WARNING ⚠️ Server must run as 845:845 to match factoriotools docker image file permissions

1. Clone the repository
   ```bash
   git clone https://github.com/behindcurtain3/factoriohq.git
   cd factoriohq
   ```

2. Install dependencies
   ```bash
   bundle install
   ```

3. Set up the database
   ```bash
   rails db:create db:migrate
   ```

4. Configure environment variables
   ```bash
   cp .env.example .env
   ```
   Edit the `.env` file and set `FACTORIO_DATA_PATH` to a directory where you want to store server files.

5. Start the server
   ```bash
   rails server
   ```

## Usage

1. Register an account and log in (first user to register will be marked as an admin)
2. Create a new Factorio server
3. Configure server settings
4. Upload save files and/or mods (optional)
5. Start the server (the first time you start a server may take a few minutes to download the image)
6. Connect to the server using the Factorio game client

## Server Management

- **Start/Stop**: Control server state from the server details page
- **Update Version**: Update Factorio version seemlessly
- **Save Files**: Upload, download, and manage save files
- **Mods**: Browse, upload, download, and manage mods
- **Logs**: View server and game logs for troubleshooting

## Development

### Background Jobs

FactorioHQ uses background jobs for server operations and log streaming:

- `ServerOperationJob`: Handles starting and stopping servers
- `StreamGameLogsJob`: Captures and stores game logs
- `ServerStatusSyncJob`: Runs when web server starts to sync server status with actual Docker container status

## License

[MIT License](LICENSE)
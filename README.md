# LR-MultiJobs

Grant your players the freedom to work several jobs at once and switch between them on-the-fly.  
LR-MultiJobs is an open-source resource for **RedM** servers powered by **VORP** that keeps job-data in MySQL and provides an in-game menu to manage every career a character owns.

---

## Features

* Store **multiple jobs per character** with their own grade & salary.
* Easily **switch** or **delete** a job through a clean VORP-Menu interface (`/myjobs`).
* **Automatic detection** of VORP events (`vorp:setJob`, `vorp:setGroup`, …) – every time a player receives a new job the script saves it.
* **Per-group slot limits** (e.g. *user* → 3 jobs, *vip* → 5, *admin* → 10).
* Simple, single-file configuration (`shared/config.lua`).
* Localised – English file provided, create your own inside `languages/`.

---

## Requirements

| Resource | Minimum version | Purpose |
|----------|-----------------|---------|
| [`vorp_core`](https://github.com/VORPCORE) | latest | character & job framework |
| [`vorp_menu`](https://github.com/VORPCORE) | latest | client menu system |
| [`oxmysql`](https://github.com/overextended/oxmysql) | 2.0+ | MySQL connector |

The script targets `fx_version 'cerulean'` and requires **Lua 5.4** (`lua54 "yes"` in `fxmanifest.lua`).

---

## Installation

1. **Import the SQL** file `extra/DB.sql` into your game database (this creates `player_jobs`).
2. **Ensure dependencies** are started **before** `lr-multijobs` in your `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure vorp_core
   ensure vorp_menu
   ensure lr-multijobs
   ```
3. (Optional) **Edit the configuration** in `shared/config.lua` to fit your needs.

---

## Configuration (`shared/config.lua`)

```lua
Config.locale       = 'en'   -- Language code (file must exist in /languages)
Config.Debug        = true   -- Print verbose info in server console

-- Max job slots for VORP groups
Config.GroupMaxJobs = {
    user  = 3,
    vip   = 5,
    admin = 10
}

Config.DefaultMaxJobs = 3    -- Fallback if group not listed above
```

Changing these values **does not** require a server restart – a simple resource restart is sufficient.

---

## Usage

### In-game commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/myjobs` | Open the job-selection menu. | Any player |
| `/addJob <id> <job> <grade>` | Give a player a new job (or update grade). | Admin (server console/`_`)|
| `/removejob <id> <job>` | Remove a stored job from a player. | Admin |

Tips & errors are translated through the locale file (`languages/en.lua`).

### Events / API

If you want to add a new job from another script simply trigger:

```lua
-- server-side
TriggerEvent('lr-multijobs:server:newJob', source, {
    name  = 'police',   -- job name string
    grade = { level = 2 } -- integer grade level
})
```

The resource also exposes the following events:

* `lr-multijobs:server:changeJob` (server) – switch the active job.
* `lr-multijobs:server:deleteJob` (server) – delete a stored job.
* `lr-multijobs:client:openmenu` (client) – open jobs menu for a player.

Internally the script listens to VORP events (`vorp:setJob`, `vorp:setGroup`, `vorp:playerJobChange`, `vorp:playerJobGradeChange`) so **no extra integration** is required for standard job changes.

---

## Database

```sql
CREATE TABLE IF NOT EXISTS `player_jobs` (
  `id` INT          NOT NULL AUTO_INCREMENT,
  `citizenid` INT   NOT NULL,
  `job` VARCHAR(50) NOT NULL,
  `grade` INT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid_job` (`citizenid`, `job`)
);
```

The table is created automatically if you run the script included in `extra/DB.sql`.

---

## Contributing

Pull requests and issue reports are welcome!  
Please follow the existing code-style and commit conventions.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/awesome`)
3. Commit your changes (`git commit -am 'feat: add awesome feature'`)
4. Push to the branch (`git push origin feature/awesome`)
5. Open a Pull Request

---

## Credits

* **CODE101** – Original author
* The **VORP** & **Overextended** teams for their frameworks

---

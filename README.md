# openwrt-led-night-mode

It is a tool for managing the brightness of LEDs on OpenWRT routers.
It allows users to automatically adjust the brightness of their router's LEDs during specified night hours to reduce light pollution and save energy.

## How it works

The program interacts with the router's cron system to schedule brightness adjustments for LEDs. By setting start and end times, you can turn off the LEDs during the night and restore them to normal brightness during the day.

## Usage

You can also list all the LEDs by using `list` command.

```sh
openwrt-led-night-mode list
```

Run the program with `install` command to add changes to cron. You can control night hours by providing `--start` and `--end` flags.

```sh
openwrt-led-night-mode install --start=22:00 --end=07:00
```

You can control which LEDs to include by `--leds` flag with LEDs splitted by commas

```sh
openwrt-led-night-mode install --start=22:00 --end=07:00 --leds=green:status,green:wan
```

You can run `uninstall` command for uninstalling configured cron's.

```sh
openwrt-led-night-mode uninstall
```

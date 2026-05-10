# systemd unit templates

Production unit files live at `/etc/systemd/system/<name>.service` on
the Tencent VM. The repo copies are the **source of truth**; if you
edit a unit, edit here, commit, then redeploy with `install.sh`.

## Units

| File | Purpose | Source-of-truth path |
|---|---|---|
| `teplanner-backend.service` | FastAPI uvicorn (2 workers, port 8000, journald) | `/etc/systemd/system/teplanner-backend.service` |
| `tesla-http-proxy.service` | Tesla VCP signed-command proxy on `127.0.0.1:4443` | `/etc/systemd/system/tesla-http-proxy.service` |
| `fleet-telemetry.service` | Tesla Fleet Telemetry consumer (writes ZMQ → backend) | `/etc/systemd/system/fleet-telemetry.service` |

## Install / update on the VM

```
sudo cp ops/systemd/teplanner-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now teplanner-backend.service
```

## Verify

```
systemctl status teplanner-backend.service
journalctl -u teplanner-backend.service -n 30 --no-pager
```

## Restart the right way

`bash start.sh -d -s` runs uvicorn from the user shell — leaves
systemd's copy still running, port conflict, processes pile up. Don't.

```
sudo systemctl restart teplanner-backend.service
```

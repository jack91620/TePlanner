#!/usr/bin/env bash
# Wipe user 241's Hub Quick Actions settings (hub.actions + hub.slots)
# so the next test run sees the fresh-user seeded defaults again.
#
# Idempotent. Re-runnable.
#
# Required env:
#   TEPLANNER_SSH_HOST  default: ubuntu@82.156.248.135
#   TEPLANNER_SSH_PASS  password for sshpass; ssh keys preferred
#   TEPLANNER_USER_ID   default: 241 (real Tesla-bound user behind
#                       the Maestro flows)
set -euo pipefail

HOST="${TEPLANNER_SSH_HOST:-ubuntu@82.156.248.135}"
UID_TO_WIPE="${TEPLANNER_USER_ID:-241}"

if [ -z "${TEPLANNER_SSH_PASS:-${SSHPASS:-}}" ]; then
  echo "reset_hub_actions: no SSHPASS env, skipping (tests will see prior state)"
  exit 0
fi

SSHPASS="${TEPLANNER_SSH_PASS:-$SSHPASS}" sshpass -e ssh -o StrictHostKeyChecking=no "$HOST" \
  "cd ~/TePlanner/backend && /home/ubuntu/miniconda3/envs/teplanner/bin/python <<PY 2>&1
import asyncio
from sqlalchemy import delete
from app.db.session import async_session
from app.db.models import UserSetting

async def main():
    async with async_session() as db:
        deleted = await db.execute(delete(UserSetting).where(
            UserSetting.user_id == ${UID_TO_WIPE},
            UserSetting.key.in_(['hub.actions', 'hub.slots']),
        ))
        await db.commit()
        print(f'wiped {deleted.rowcount} hub.* rows for user ${UID_TO_WIPE}')

asyncio.run(main())
PY"

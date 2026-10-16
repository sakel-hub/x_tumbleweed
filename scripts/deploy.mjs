/**
 * Deploy code to CDB
 * Copyright (C) 2025 SaKeL
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see <https://www.gnu.org/licenses/>.
 */

import fetch from 'node-fetch'
import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'
import 'dotenv/config'

const argv = yargs(hideBin(process.argv)).argv

try {
    const token = process.env.CONTENT_DB_X_TUMBLEWEED_TOKEN || process.env.CONTENT_DB_TOKEN || argv.token
    if (!token) {
        console.error('Error: Missing ContentDB token! Provide CONTENT_DB_X_TUMBLEWEED_TOKEN or pass --token=<token>.')
        process.exit(1)
    }

    const title = argv.title ?? argv.tag
    if (!title) {
        console.error('Error: Missing release title/tag! Pass --title=<title>.')
        process.exit(1)
    }

    const ref = argv.ref ?? title ?? 'main'

    const body = {
        method: 'git',
        title: title,
        ref: ref
    }

    const response = await fetch('https://content.luanti.org/api/packages/SaKeL/x_tumbleweed/releases/new/', {
        method: 'POST',
        body: JSON.stringify(body),
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`
        }
    })
    const data = await response.json()

    console.log(data)

    if (!data.success) {
        process.exit(1)
    }
} catch (error) {
    console.log(error)
    process.exit(1)
}

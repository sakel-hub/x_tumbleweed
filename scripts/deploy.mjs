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
 * License along with this library; if not, write to juraj.vajda@gmail.com
 */

import fetch from 'node-fetch'
import yargs from 'yargs/yargs'
import { hideBin } from 'yargs/helpers'
import 'dotenv/config'

const argv = yargs(hideBin(process.argv)).argv

try {
    const body = {
        method: 'git',
        title: argv.title,
        ref: 'master'
    }

    const response = await fetch('https://content.luanti.org/api/packages/SaKeL/x_tumbleweed/releases/new/', {
        method: 'POST',
        body: JSON.stringify(body),
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${process.env.CONTENT_DB_X_TUMBLEWEED_TOKEN ?? argv.token}`
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

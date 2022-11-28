#! /usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import sys
import os.path
import yaml
import argparse

# Parse args to figure out what to generate.
parser = argparse.ArgumentParser(
    description='Generate Glean telemetry definitions from YAML sources')
parser.add_argument('input', metavar='INPUT', type=str, action='store',
    help='Glean metrics file to parse')
parser.add_argument('-o', '--output', metavar='FILE', type=str, action='store',
    help='Write output to FILE')
parser.add_argument('-f', '--format', metavar='FORMAT', type=str, action='store',
    default='cpp',
    help='Set the output format (default: cpp)')
args = parser.parse_args()

# Converts snake case into camel case.
def camelize(string):
    output = ''
    first = True
    for chunk in string.split('_'):
        if first:
            output += chunk
            first = False
        else:
            output += chunk[0].upper()
            output += chunk[1:]
    return output

# Parse the metrics file.
with open(args.input, 'r', encoding='utf-8') as fin:
    metrics = yaml.safe_load(fin)

# Prepare the output file
if args.output:
    fout = open(args.output, 'w', encoding='utf-8')
else:
    fout = sys.stdout

if args.format == 'cpp':
    print("Generating the C++ header...", file=sys.stderr)
    fout.write("""/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// AUTOGENERATED! DO NOT EDIT!!

namespace GleanSample {

""")
    for key in metrics['sample']:
        sampleName = camelize(key)
        fout.write(f"constexpr const char* {sampleName} = \"{sampleName}\";\n")

    fout.write("""
} // GleanSample
""")
    fout.close()

elif args.format == 'kotlin':
    print("Generating the Kotlin enum...", file=sys.stderr)
    fout.write("""/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// AUTOGENERATED! DO NOT EDIT!!
package org.mozilla.firefox.vpn.glean

import android.annotation.SuppressLint

@SuppressLint("Unused")
enum class GleanEvent(val key: String) {
""")
    for key in metrics['sample']:
        sampleName = camelize(key)
        fout.write(f"\t {sampleName}(\"{sampleName}\"),\n")

    fout.write("""
} // GleanSample
""")

else:
    print(f'Unknown output format: {args.format}', file=sys.stderr)
    sys.exit(1)
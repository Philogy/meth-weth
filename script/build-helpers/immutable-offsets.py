import sys
from Crypto.Hash import keccak as _keccak
import re
import subprocess

IMMUTABLES = [
    'meth.placeholders.domainSeparator'
]


def keccak(inp: str) -> bytes:
    return _keccak.new(data=inp.encode(), digest_bits=256).digest()


OP_RETURN = 0xf3
PUSH_OPS = [*range(0x60, 0x80)]


def find_opcodes(bytecode, op):
    i = 0
    while (byte := bytecode[i]) != op:
        if byte in PUSH_OPS:
            i += (byte & 0x1f) + 1
        i += 1
    return i


def main():
    contract_fp = sys.argv[1]
    bytecode = bytes.fromhex(subprocess.getoutput(f'huffc -b {contract_fp}'))
    constructor_end = find_opcodes(bytecode, OP_RETURN) + 1
    print(f'constructor size: 0x{constructor_end:x} ({constructor_end:,})')
    runtime_bytecode = bytecode[constructor_end:]
    for im in IMMUTABLES:
        placeholder_bytes = keccak(im)
        positions = [
            *re.finditer(b'\x7f' + placeholder_bytes, runtime_bytecode)
        ]
        if positions:
            print(f'"{im}" (0x{placeholder_bytes.hex()}) instances:')
            for i, pos in enumerate(positions, start=1):
                offset = pos.start() + 1
                print(f'  - #{i} => 0x{offset:x} ({offset:,})')
        else:
            print(
                f'No instances of "{im}" (0x{placeholder_bytes.hex()}) found')


if __name__ == '__main__':
    main()

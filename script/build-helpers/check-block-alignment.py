import subprocess
import sys

SIZE = 64
BLOCKS = 256

JUMPDEST = 0x5b


def main():
    direct_out = subprocess.getoutput('huffc -r src/METH_WETH.huff')
    out = direct_out.splitlines()[-1]

    runtime_bytecode = bytes.fromhex(out)

    print(f'dispatcher head:\n     0x{runtime_bytecode[:SIZE - 1].hex()}')

    for block in range(0, BLOCKS):
        block_offset = (SIZE - 1) + SIZE * block

        print(
            f'block 0x{block:02x}:\n    0x{runtime_bytecode[block_offset:block_offset + SIZE].hex()}'
        )

        if runtime_bytecode[block_offset] != JUMPDEST:
            print(
                f'WARNING: Missing selectors 0x{block:02x}000000 - 0x{block:02x}ffffff'
            )


if __name__ == '__main__':
    main()
